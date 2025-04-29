import os
import json
import time
from flask import Flask, request, jsonify
from flask_cors import CORS
from openai import OpenAI
import re

# Initialize OpenAI client
client = OpenAI(api_key="")

app = Flask(__name__)
CORS(app, resources={r"/api/*": {"origins": "*"}})

# Load datasets

def load_json(path):
    with open(path) as f:
        return json.load(f)

# All JSON sources
projects = load_json("projects.json") + load_json("projects (1).json")
mentorships = load_json("mentorships.json")
mentoring_templates = load_json("mentoring_templates.json")
mentoring_programs = load_json("mentoring_programs.json")
case_templates = load_json("case_templates.json")
custom_case_templates = load_json("customized_case_templates.json")
case_programs = load_json("case_programs.json")
case_libraries = load_json("case_libraries.json")
articles = load_json("articles.json")

career_keywords = {
    "marketing": ["marketing", "brand", "gtm"],
    "data-science": ["data", "analytics", "forecast", "predictive"],
    "ai": ["ai", "artificial intelligence", "machine learning"],
    "finance": ["finance", "financial", "returns"],
    "cybersecurity": ["cyber", "nist", "compliance"],
    "career-exploration": ["job search", "career", "exploration"],
    "resume-building": ["resume", "cv", "candidate"],
    "communication": ["communication", "public speaking"],
    "design": ["design", "ux", "interface"],
    "healthcare": ["health", "preventive", "care"]
}

def tag_text(text):
    tags = set()
    text = text.lower()
    for tag, keywords in career_keywords.items():
        if any(k in text for k in keywords):
            tags.add(tag)
    return list(tags)

def truncate(text, limit=100):
    return text if len(text) <= limit else text[:limit].rstrip() + "..."

def summarize_title(text):
    parts = re.split(r"[:\-–]\s*", text, maxsplit=1)
    return parts[0] if parts else text

opportunities = []

def add_opportunity(data, otype, filter_fn=None):
    for item in data:
        if item.get("title") and (filter_fn is None or filter_fn(item)):
            opportunities.append({
                "type": otype,
                "title": item["title"],
                "slug": item.get("slug"),
                "tags": tag_text(item["title"]),
                "summary": summarize_title(item["title"])
            })

add_opportunity(projects, "project", lambda x: x.get("status") == "approved")
add_opportunity(mentorships, "mentorship")
add_opportunity(mentoring_templates, "mentoring_template")
add_opportunity(mentoring_programs, "mentoring_program", lambda x: x.get("status") == "published")
add_opportunity(case_templates, "case", lambda x: x.get("status") == "published")
add_opportunity(custom_case_templates, "custom_case")
add_opportunity(case_programs, "case_program")
add_opportunity(case_libraries, "case_library")
add_opportunity(articles, "article")

session_memory = {}
FEEDBACK_FILE = "feedback_log.json"

def log_feedback(feedback_data):
    try:
        with open(FEEDBACK_FILE, "a") as f:
            json.dump(feedback_data, f)
            f.write("\n")
    except Exception as e:
        print("Feedback logging error:", e)

def match_opportunities(user_input):
    keywords = re.findall(r"\w+", user_input.lower())
    matches = []
    for o in opportunities:
        if any(kw in o["title"].lower() for kw in keywords) or any(kw in o["tags"] for kw in keywords):
            matches.append(o)
    return matches[:5]

@app.route("/api/chat", methods=["POST"])
def chat():
    try:
        data = request.get_json()
        user_input = data.get("message")
        session_id = data.get("sessionId", "default")
        role = data.get("role", None)

        if not user_input:
            return jsonify({"error": "Missing message"}), 400

        history = session_memory.get(session_id, [])
        history.append({"role": "user", "content": user_input})

        role_context = f"The user is a {role}." if role else "The user role is unknown."
        system_prompt = (
            "You are CapChat, an AI chatbot for CapSource. Use https://capsource.io as a reference. "
            "You help users explore mentorships, projects, programs, cases, articles, and career paths. Be helpful and short. "
            f"{role_context}"
        )

        messages = [{"role": "system", "content": system_prompt}] + history[-10:]

        completion = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages
        )
        response_text = completion.choices[0].message.content.strip()

        matches = match_opportunities(user_input)
        if matches:
            bullet_list = []
            response_text += "\n\n🔍 Based on your interest, here are some matching opportunities:\n"
            for m in matches:
                type_emoji = {
                    "project": "📁",
                    "mentorship": "🎓",
                    "mentoring_template": "🧭",
                    "mentoring_program": "👥",
                    "case": "📄",
                    "custom_case": "⚙️",
                    "case_program": "📘",
                    "case_library": "🏛️",
                    "article": "📚"
                }.get(m["type"], "📌")

                title = truncate(m['summary'])
                line = f"{type_emoji} **{m['type'].replace('_', ' ').capitalize()}**: {title}"
                if m.get("slug"):
                    line += f"\n🔗 /{m['type']}/{m['slug']}"
                bullet_list.append(line)

            response_text += "\n\n" + "\n\n".join(bullet_list) + "\n"

        history.append({"role": "assistant", "content": response_text})
        session_memory[session_id] = history

        return jsonify({"response": response_text})

    except Exception as e:
        print("Error:", str(e))
        return jsonify({"error": str(e)}), 500

@app.route("/api/feedback", methods=["POST"])
def feedback():
    try:
        data = request.get_json()
        feedback_entry = {
            "timestamp": time.time(),
            "message": data.get("message"),
            "feedback": data.get("feedback"),
            "role": data.get("role"),
            "sessionId": data.get("sessionId")
        }
        log_feedback(feedback_entry)
        return jsonify({"status": "success"})
    except Exception as e:
        print("Feedback error:", str(e))
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    print("Starting CapChat Flask app on port 5000")
    app.run(debug=True, port=5000)

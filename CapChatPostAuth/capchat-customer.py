# capchat_customer.py

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

# Load datasets (replace with actual paths)
def load_json(path):
    with open(path) as f:
        return json.load(f)

projects = load_json("projects.json") + load_json("projects (1).json")
mentorships = load_json("mentorships.json")
mentoring_programs = load_json("mentoring_programs.json")
case_programs = load_json("case_programs.json")
articles = load_json("articles.json")

# Keywords for customer interests
customer_keywords = {
    "experiential-learning": ["experiential", "project-based", "curriculum", "real world"],
    "recruitment": ["recruit", "talent", "pipeline", "interns"],
    "partnership": ["partner", "collaborate", "sponsor"],
    "outcomes": ["impact", "outcomes", "success"],
    "platform-features": ["platform", "dashboard", "workflow"]
}

def tag_text(text):
    tags = set()
    text = text.lower()
    for tag, keywords in customer_keywords.items():
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

add_opportunity(projects, "project")
add_opportunity(mentorships, "mentorship")
add_opportunity(mentoring_programs, "mentoring_program")
add_opportunity(case_programs, "case_program")
add_opportunity(articles, "article")

session_memory = {}
FEEDBACK_FILE = "feedback_customer_log.json"

def log_feedback(feedback_data):
    try:
        with open(FEEDBACK_FILE, "a") as f:
            json.dump(feedback_data, f)
            f.write("\n")
    except Exception as e:
        print("Feedback logging error:", e)

def match_opportunities(user_input):
    keywords = set(re.findall(r"\w+", user_input.lower()))
    matches = []
    for o in opportunities:
        title_words = set(re.findall(r"\w+", o["title"].lower()))
        tag_words = set(o["tags"])
        if len(keywords & (title_words | tag_words)) >= 2:
            matches.append(o)
    return matches[:5]

@app.route("/api/chat", methods=["POST"])
def chat():
    try:
        data = request.get_json()
        user_input = data.get("message")
        session_id = data.get("sessionId", "default")
        role = data.get("role", "visitor")

        if not user_input:
            return jsonify({"error": "Missing message"}), 400

        history = session_memory.get(session_id, [])
        history.append({"role": "user", "content": user_input})

        role_context = f"The user is a {role}. This user may represent a university, academic institution, or a company interested in using CapSource."
        system_prompt = (
            "You are CapChat, an AI chatbot designed to assist potential CapSource customers."
            " Use https://capsource.io as a reference."
            " Provide clear, professional responses that highlight CapSource’s benefits for educators, administrators, and corporate partners."
            f" {role_context}"
        )

        messages = [{"role": "system", "content": system_prompt}] + history[-10:]

        completion = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages
        )
        response_text = completion.choices[0].message.content.strip()

        # Add follow-up question to ask about projects
        follow_up_prompt = "\n\nWould you like to see some example CapSource opportunities or projects that match your interests?"
        response_text += follow_up_prompt

        history.append({"role": "assistant", "content": response_text})
        session_memory[session_id] = history

        return jsonify({"response": response_text})

    except Exception as e:
        print("Error:", str(e))
        return jsonify({"error": str(e)}), 500

@app.route("/api/opportunities", methods=["POST"])
def show_opportunities():
    try:
        data = request.get_json()
        user_input = data.get("message")

        matches = match_opportunities(user_input)
        if matches:
            response_text = "🔍 Here are some CapSource opportunities based on your interests:\n"
            bullet_list = []
            for m in matches:
                type_emoji = {
                    "project": "📁",
                    "mentorship": "🎓",
                    "mentoring_program": "👥",
                    "case_program": "📘",
                    "article": "📚"
                }.get(m["type"], "📌")

                title = truncate(m['summary'])
                line = f"{type_emoji} **{m['type'].replace('_', ' ').capitalize()}**: {title}"
                if m.get("slug"):
                    line += f"\n🔗 /{m['type']}/{m['slug']}"
                bullet_list.append(line)

            response_text += "\n\n" + "\n\n".join(bullet_list) + "\n"
            return jsonify({"response": response_text})
        else:
            return jsonify({"response": "No relevant opportunities found at this time."})

    except Exception as e:
        print("Opportunity error:", str(e))
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
    print("Starting CapChat Customer Flask app on port 5001")
    app.run(debug=True, port=5001)
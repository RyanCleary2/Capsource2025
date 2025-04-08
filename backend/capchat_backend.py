from flask import Flask, request, jsonify
from flask_cors import CORS
import openai
from ragFirstDraft import process_user_input
import os
import json
import time

openai.api_key = os.getenv("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")

app = Flask(__name__)
CORS(app)

session_memory = {}

FEEDBACK_FILE = "feedback_log.json"

def log_feedback(feedback_data):
    try:
        with open(FEEDBACK_FILE, "a") as f:
            json.dump(feedback_data, f)
            f.write("\n")
    except Exception as e:
        print("Feedback logging error:", e)

@app.route("/chat", methods=["POST"])
def chat():
    data = request.get_json()
    user_input = data.get("message")
    session_id = data.get("sessionId", "default")
    role = data.get("role", None)

    if not user_input:
        return jsonify({"error": "Missing message"}), 400

    processed = process_user_input(user_input)
    history = session_memory.get(session_id, [])
    history.append({"role": "user", "content": user_input})

    if processed["clarification_needed"]:
        response_text = processed["response"]
    else:
        role_context = f"The user is a {role}." if role else "The user role is unknown."
        system_prompt = (
            "You are CapChat, an AI chatbot for CapSource. You help users explore mentorship, projects, and career paths. "
            "Keep your responses short, helpful, and conversational. Avoid long lists. Respond in 2–4 sentences max. "
            "Use bullet points only when necessary. Prioritize clarity and friendliness. This is a chat, not a lecture."
            "If needed, offer to follow up with more details. The user is a "
            f"{role}."
        )


        messages = [{"role": "system", "content": system_prompt}] + history[-10:]

        try:
            completion = openai.ChatCompletion.create(
                model="gpt-4o",
                messages=messages
            )
            response_text = completion.choices[0].message.content
        except Exception as e:
            return jsonify({"error": str(e)}), 500

    history.append({"role": "assistant", "content": response_text})
    session_memory[session_id] = history

    return jsonify({"response": response_text})

@app.route("/feedback", methods=["POST"])
def feedback():
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

if __name__ == "__main__":
    app.run(debug=True, port=5000)

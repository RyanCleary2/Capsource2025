import os
from dotenv import load_dotenv
import openai
from flask import Flask, render_template, request
from flask_cors import CORS

# Initialize Flask app
app = Flask(__name__)

# Enable CORS for all routes
CORS(app)

# Load environment variables from .env file
load_dotenv()

# Set up the OpenAI client
api_key = os.getenv("OPENAI_API_KEY")
if not api_key:
    raise ValueError("API key is missing. Please set the OPENAI_API_KEY in your .env file.")

client = openai.OpenAI(api_key=api_key)

def generate_project_scope(url, goal):
    """Generate a full CapSource project scope using OpenAI."""
    try:
        prompt = f"""
        Given the company website: {url}, and their goal: "{goal}", generate a full CapSource project scope with the following structure:
        Project Title
        Challenge/Opportunity (150–200 words)
        Action Items (bulleted list)
        Measuring Success (bulleted list)
        Topics Covered (bulleted list)
        Milestones 1–5 (title, guiding questions, suggested deliverables)
        Helpful Public Resources (links + 1-line description)
        """
        print(f"Sending prompt to OpenAI: {prompt}")  # Debug log
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=1000,
            temperature=0.7,
        )
        message = response.choices[0].message.content.strip()
        if not message:
            print("Empty response content from OpenAI.")
            return None
        print(f"Received response from OpenAI: {message}")  # Debug log
        return message
    except openai.OpenAIError as e:
        print(f"OpenAI API error: {str(e)}")  # More specific error logging
        return None
    except Exception as e:
        print(f"Unexpected error in generate_project_scope: {str(e)}")
        return None

# Route to render the HTML page (index.html)
@app.route('/')
def home():
    print("Rendering index.html")  # Debug log
    return render_template('index.html')

# Route to handle the project generation logic (POST request)
@app.route('/generate_project', methods=['POST'])
def generate_project():
    print("Received POST request to /generate_project")  # Debug log
    website_url = request.form.get('website-url')
    goal_statement = request.form.get('background')

    if not website_url or not goal_statement:
        print("Missing website URL or goal statement")  # Debug log
        return render_template('index.html', error="Missing website URL or goal statement")

    project_scope = generate_project_scope(website_url, goal_statement)
    
    if project_scope:
        print("Project scope generated successfully")  # Debug log
        return render_template('result.html', project_scope=project_scope)
    else:
        print("Failed to generate project scope")  # Debug log
        return render_template('index.html', error="Failed to generate project scope. Check server logs for details.")

if __name__ == '__main__':
    print("Starting Flask app on port 5000")  # Debug log
    app.run(debug=True)
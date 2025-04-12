import os
from dotenv import load_dotenv
import openai
from flask import Flask, render_template, request
from flask_cors import CORS

# Initialize Flask application instance
app = Flask(__name__)

# Enable Cross-Origin Resource Sharing for all routes
CORS(app)

# Load environment variables from .env file in the project root
load_dotenv()

# Retrieve OpenAI API key from environment variables
api_key = os.getenv("OPENAI_API_KEY")
if not api_key:
    raise ValueError("API key is missing. Please set the OPENAI_API_KEY in your .env file.")

# Initialize OpenAI client with the API key
client = openai.OpenAI(api_key=api_key)

def generate_project_ideas(url, topics):
    """Generate a list of project ideas based on company website and selected topics."""
    try:
        prompt = f"""
        Given the company website: {url}, and the selected topics: {', '.join(topics)},
        generate 3-5 concise project ideas (50-100 words each) that align with the company's context
        and the selected topics. Each idea should include:
        - A title
        - A brief description
        Format the response as a numbered list.
        """
        print(f"Sending prompt to OpenAI for ideas: {prompt}")
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=500,
            temperature=0.8,
        )
        message = response.choices[0].message.content.strip()
        if not message:
            print("Empty response content from OpenAI for ideas.")
            return None
        print(f"Received response from OpenAI for ideas: {message}")
        return message
    except openai.OpenAIError as e:
        print(f"OpenAI API error in generate_project_ideas: {str(e)}")
        return None
    except Exception as e:
        print(f"Unexpected error in generate_project_ideas: {str(e)}")
        return None

def generate_project_scope(url, goal):
    """Generate a full CapSource project scope using OpenAI API."""
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
        print(f"Sending prompt to OpenAI for scope: {prompt}")
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=1000,
            temperature=0.7,
        )
        message = response.choices[0].message.content.strip()
        if not message:
            print("Empty response content from OpenAI for scope.")
            return None
        print(f"Received response from OpenAI for scope: {message}")
        return message
    except openai.OpenAIError as e:
        print(f"OpenAI API error in generate_project_scope: {str(e)}")
        return None
    except Exception as e:
        print(f"Unexpected error in generate_project_scope: {str(e)}")
        return None

@app.route('/')
def home():
    """Render the index.html template as the homepage."""
    print("Rendering index.html")
    return render_template('index.html')

@app.route('/generate_project', methods=['POST'])
def generate_project():
    """Handle project generation based on form input and render results."""
    print("Received POST request to /generate_project")
    website_url = request.form.get('website-url')
    mode = request.form.get('mode', 'scope')  # Default to 'scope' if not provided

    print(f"Mode received: {mode}")
    print(f"Form data: {request.form}")

    if not website_url:
        print("Missing website URL")
        return render_template('index.html', error="Missing website URL")

    if mode == 'ideas':
        topics = request.form.getlist('topics')  # Get list of selected topics from checkboxes
        print(f"Topics selected: {topics}")
        if not topics:
            print("Missing topics for ideas mode")
            return render_template('index.html', error="Please select at least one topic for project ideas")
        project_ideas = generate_project_ideas(website_url, topics)
        if project_ideas:
            print("Project ideas generated successfully")
            return render_template('result.html', project_ideas=project_ideas, website_url=website_url, mode='ideas')
        else:
            print("Failed to generate project ideas")
            return render_template('index.html', error="Failed to generate project ideas. Check server logs for details.")
    else:
        goal_statement = request.form.get('background')
        if not goal_statement:
            print("Missing goal statement for scope mode")
            return render_template('index.html', error="Missing goal statement")
        project_scope = generate_project_scope(website_url, goal_statement)
        if project_scope:
            print("Project scope generated successfully")
            return render_template('result.html', project_scope=project_scope, mode='scope')
        else:
            print("Failed to generate project scope")
            return render_template('index.html', error="Failed to generate project scope. Check server logs for details.")

@app.route('/generate_scope_from_idea', methods=['POST'])
def generate_scope_from_idea():
    """Generate a full project scope from a selected project idea."""
    print("Received POST request to /generate_scope_from_idea")
    website_url = request.form.get('website_url')
    project_idea = request.form.get('project_idea')

    if not website_url or not project_idea:
        print("Missing website URL or project idea")
        return render_template('index.html', error="Missing website URL or project idea")

    project_scope = generate_project_scope(website_url, project_idea)
    if project_scope:
        print("Full scope generated successfully from idea")
        return render_template('result.html', project_scope=project_scope, mode='scope')
    else:
        print("Failed to generate full scope from idea")
        return render_template('index.html', error="Failed to generate full scope. Check server logs for details.")

if __name__ == '__main__':
    print("Starting Flask app on port 5000")
    app.run(debug=True)
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
    # Raise an error if the API key is not found
    raise ValueError("API key is missing. Please set the OPENAI_API_KEY in your .env file.")

# Initialize OpenAI client with the API key
client = openai.OpenAI(api_key=api_key)

def generate_project_scope(url, goal):
    """Generate a full CapSource project scope using OpenAI API."""
    try:
        # Define the prompt structure for OpenAI to generate a project scope
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
        print(f"Sending prompt to OpenAI: {prompt}")  # Log the prompt for debugging
        # Send request to OpenAI API to generate the project scope
        response = client.chat.completions.create(
            model="gpt-4o-mini",  # Specify the model to use
            messages=[{"role": "user", "content": prompt}],  # User message with prompt
            max_tokens=1000,  # Limit the response length
            temperature=0.7,  # Control creativity of the response
        )
        # Extract the generated content from the response
        message = response.choices[0].message.content.strip()
        if not message:
            print("Empty response content from OpenAI.")  # Log if response is empty
            return None
        print(f"Received response from OpenAI: {message}")  # Log the response for debugging
        return message
    except openai.OpenAIError as e:
        # Handle specific OpenAI API errors
        print(f"OpenAI API error: {str(e)}")  # Log the error
        return None
    except Exception as e:
        # Handle any other unexpected errors
        print(f"Unexpected error in generate_project_scope: {str(e)}")  # Log the error
        return None

# Define route for the homepage
@app.route('/')
def home():
    """Render the index.html template as the homepage."""
    print("Rendering index.html")  # Log for debugging
    return render_template('index.html')

# Define route to handle project generation via POST request
@app.route('/generate_project', methods=['POST'])
def generate_project():
    """Handle project generation based on form input and render results."""
    print("Received POST request to /generate_project")  # Log for debugging
    # Extract form data
    website_url = request.form.get('website-url')
    goal_statement = request.form.get('background')

    # Validate that required fields are provided
    if not website_url or not goal_statement:
        print("Missing website URL or goal statement")  # Log missing input
        return render_template('index.html', error="Missing website URL or goal statement")

    # Generate project scope using the provided inputs
    project_scope = generate_project_scope(website_url, goal_statement)
    
    if project_scope:
        # If successful, render the result page with the generated scope
        print("Project scope generated successfully")  # Log success
        return render_template('result.html', project_scope=project_scope)
    else:
        # If generation fails, return to index with an error message
        print("Failed to generate project scope")  # Log failure
        return render_template('index.html', error="Failed to generate project scope. Check server logs for details.")

if __name__ == '__main__':
    # Start the Flask development server if this file is run directly
    print("Starting Flask app on port 5000")  # Log server start
    app.run(debug=True)  # Run in debug mode on default port 5000
import os
from dotenv import load_dotenv
import openai

# Load environment variables from .env file
load_dotenv()

# Set up the OpenAI client
api_key = os.getenv("OPENAI_API_KEY")
if not api_key:
    raise ValueError("OpenAI API key is not set. Please set the OPENAI_API_KEY environment variable.")
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

        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=1000,
            temperature=0.7,
        )

        message = response.choices[0].message.content.strip()
        if not message:
            print("Empty response content.")
            return None
        return message

    except openai.OpenAIError as e:
        print(f"Error generating project scope: {e}")
        return None

if __name__ == "__main__":
    website_url = input("Enter the company website URL: ")
    goal_statement = input("Enter the company's goal statement: ")

    project_scope = generate_project_scope(website_url, goal_statement)

    if project_scope:
        print("\nGenerated Project Scope:")
        print(project_scope)

import random
import datetime
import time
import os
import openai
import requests
from bs4 import BeautifulSoup

# Set up the OpenAI API key

# Global project ID counter
project_id_counter = 1000

# OpenAI API Key (Ensure this is securely stored in a config file or environment variable)

def generate_project_id():
    global project_id_counter
    project_id_counter += 1
    return project_id_counter

def generate_random_date():
    return datetime.datetime.now().strftime('%B %d, %Y %H:%M')

def fetch_company_details(url):
    """Fetch key details about the company from the given website URL."""
    try:
        response = requests.get(url)
        if response.status_code == 200:
            soup = BeautifulSoup(response.text, "html.parser")

            # Extract the title of the page as the company name
            company_name = soup.title.string.strip() if soup.title else "Unknown Company"

            # Extract meta description for background and objective
            meta_description = soup.find("meta", attrs={"name": "description"})
            background_objective = meta_description["content"].strip() if meta_description else "No background information available."

            return {
                "Company": company_name,
                "Background & Objective": background_objective
            }
        else:
            print(f"Failed to fetch the website. Status code: {response.status_code}")
            return None
    except Exception as e:
        print(f"Error fetching company details: {e}")
        return None

import openai
from openai import OpenAI

client = OpenAI()
import time

def generate_missing_detail(project_details, field):
    try:
        category = project_details.get("Category", "General")
        company = project_details.get("Company", "Unknown Company")
        background_objective = project_details.get("Background & Objective", "No background information available.")

        prompts = {
            "Title": f"Generate a relevant project title for a {category} project.",
            "Program": f"Suggest a program name for a {category} project related to {company}.",
            "Key Action Items": f"List three key action items for a {category} project at {company}.",
            "Ways To Measure Success": f"Describe how success will be measured for a {category} project at {company}."
        }

        prompt = prompts.get(field, f"Generate relevant information for a {category} project.")
        response = client.chat.completions.create(model="gpt-3.5-turbo",  # Use a model you have access to
        messages=[{"role": "user", "content": prompt}])
        return response.choices[0].message.content.strip()
    except openai.RateLimitError:
        print("Rate limit exceeded. Retrying after a delay...")
        time.sleep(10)  # Wait 10 seconds before retrying
        return generate_missing_detail(project_details, field)

def generate_mock_project(project_details):
    project_id = generate_project_id()

    if not project_details.get("Company") or not project_details.get("Background & Objective"):
        print("AI Project Build Error: Missing Key Details")
        return None

    title = project_details.get("Title", generate_missing_detail(project_details, "Title"))
    company = project_details.get("Company", "Unknown Company")
    program = project_details.get("Program", generate_missing_detail(project_details, "Program"))
    status = project_details.get("Status", "Pending")

    background_objective = project_details.get("Background & Objective")
    key_action_items = project_details.get("Key Action Items", generate_missing_detail(project_details, "Key Action Items"))
    ways_to_measure_success = project_details.get("Ways To Measure Success", generate_missing_detail(project_details, "Ways To Measure Success"))

    project = {
        "Id": project_id,
        "Title": title,
        "Status": status,
        "Company": company,
        "Program": program,
        "Created At": generate_random_date(),
        "Background & Objective": background_objective,
        "Key Action Items": key_action_items,
        "Ways To Measure Success": ways_to_measure_success
    }
    return project

if __name__ == "__main__":
    # Example: Provide a website URL
    website_url = input("Enter the company website URL: ")

    # Fetch company details from the website
    company_details = fetch_company_details(website_url)

    if company_details:
        # Generate a mock project based on the fetched details
        mock_project = generate_mock_project(company_details)

        if mock_project:
            print("\nGenerated Project:")
            for key, value in mock_project.items():
                print(f"{key}: {value}")
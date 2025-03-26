import random
import datetime
import pandas as pd
import openai

# Global project ID counter
project_id_counter = 1000

# OpenAI API Key (Ensure this is securely stored in a config file or environment variable)
openai.api_key = "your_openai_api_key"

def generate_project_id():
    global project_id_counter
    project_id_counter += 1
    return project_id_counter

def generate_random_date():
    return datetime.datetime.now().strftime('%B %d, %Y %H:%M')

def load_project_details_from_excel(file_path):
    df = pd.read_excel(file_path)
    return df.to_dict(orient='records')

def generate_missing_detail(project_details, field):
    """Use OpenAI API to infer missing project details based on the provided context."""
    category = project_details.get("Category")
    if not category:
        category_prompt = "Infer the category (The industry of the company) based on the given project details."
        response = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[{"role": "user", "content": category_prompt}]
        )
        category = response['choices'][0]['message']['content'].strip()
    
    company = project_details.get("Company")
    background_objective = project_details.get("Background & Objective")
    
    if not company or not background_objective:
        print("AI Project Build Error: Missing Key Details")
        return "Null"
    
    prompts = {
        "Title": f"Generate a relevant project title for a {category} project.",
        "Program": f"Suggest a program name for a {category} project related to {company}.",
        "Background & Objective": f"Describe the objectives and background for a {category} project titled '{project_details.get('Title', 'a project')}' at {company}.",
        "Key Action Items": f"List three key action items for a {category} project titled '{project_details.get('Title', 'a project')}' at {company}.",
        "Ways To Measure Success": f"Describe how success will be measured for a {category} project titled '{project_details.get('Title', 'a project')}' at {company}."
    }
    
    prompt = prompts.get(field, f"Generate relevant information for a {category} project.")
    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[{"role": "user", "content": prompt}]
    )
    return response['choices'][0]['message']['content'].strip()

def generate_mock_project(project_details):
    project_id = generate_project_id()
    
    if not project_details.get("Company") or not project_details.get("Background & Objective"):
        print("AI Project Build Error: Missing Key Details")
        return None
    
    title = project_details.get("Title", generate_missing_detail(project_details, "Title"))
    company = project_details.get("Company", "Null")
    owner = project_details.get("Owner", "Null")
    program = project_details.get("Program", generate_missing_detail(project_details, "Program"))
    status = project_details.get("Status", "Pending")
    
    background_objective = project_details.get("Background & Objective")
    key_action_items = project_details.get("Key Action Items", generate_missing_detail(project_details, "Key Action Items"))
    ways_to_measure_success = project_details.get("Ways To Measure Success", generate_missing_detail(project_details, "Ways To Measure Success"))
    
    project = {
        "Id": project_id,
        "Title": title,
        "Front End Link": title,
        "Status": status,
        "Company": company,
        "Front End Link Program": program,
        "Owner": owner,
        "Program": program,
        "Old": "Empty",
        "Created At": generate_random_date(),
        "Notify Meeting At": "Empty",
        "Visibility": "All Users",
        "Topic": "Empty",
        "Compensation Settings": project_details.get("Compensation Settings", "Null"),
        "Sponsorship Settings": project_details.get("Sponsorship Settings", "Null"),
        "Overview": "Empty",
        "Background & Objective": background_objective,
        "Key Action Items": key_action_items,
        "Ways To Measure Success": ways_to_measure_success
    }
    return project

if __name__ == "__main__":
    file_path = "project_details.xlsx"  # Specify your Excel file path
    project_data_list = load_project_details_from_excel(file_path)
    for project_data in project_data_list:
        mock_project = generate_mock_project(project_data)
        if mock_project:
            for key, value in mock_project.items():
                print(f"{key}: {value}")

import requests
from bs4 import BeautifulSoup
import os

# Define headers to mimic a browser visit
headers = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36"
}

# Read case links from file
with open("case_links.txt", "r") as file:
    case_links = [line.strip() for line in file if line.strip()]

# Create a folder to store case details
os.makedirs("case_data", exist_ok=True)

def get_section(soup, title_text):
    """Finds a section based on title text."""
    section = soup.find("td", class_="opencase-show-td", string=title_text)
    return section.find_next("td", class_="opencase-show-td-paragraph").get_text("\n", strip=True) if section else "Section Not Found"

# Loop through each case link
for case_url in case_links:
    print(f"Scraping: {case_url}")
    
    # Fetch webpage content
    response = requests.get(case_url, headers=headers)

    if response.status_code == 200:
        soup = BeautifulSoup(response.text, "html.parser")

        # Extract case title
        title_element = soup.find("h4", class_="f-24")
        title = title_element.get_text(strip=True) if title_element else "Title Not Found"

        # Extract topics
        topics = [span.get_text(strip=True) for span in soup.find_all("span", class_="mb-1 badge rounded-pill text-dark bg-secondary")]

        # Extract different sections
        background_objective = get_section(soup, "Background and Objective")
        key_action_items = get_section(soup, "Key Action Items")
        ways_to_measure_success = get_section(soup, "Ways to Measure Success")

        # Extract milestones
        milestones = []
        milestone_headers = soup.find_all("h6", class_="fw-bold")
        for header in milestone_headers:
            milestone_title = header.get_text(strip=True)
            milestone_description = header.find_next("p", class_="f-16").get_text(strip=True) if header.find_next("p", class_="f-16") else "No description provided"
            milestones.append(f"{milestone_title}: {milestone_description}")

        # Format the output
        output = f"""
Title: {title}

Topics: {", ".join(topics) if topics else "No Topics Found"}

### Background and Objective:
{background_objective}

### Key Action Items:
{key_action_items}

### Ways to Measure Success:
{ways_to_measure_success}

### Milestones:
{chr(10).join(milestones)}
"""

        # Save to a text file using a safe filename
        safe_filename = title.replace(" ", "_").replace("/", "_")[:50]  # Avoid long or unsafe filenames
        file_path = os.path.join("case_data", f"{safe_filename}.txt")

        with open(file_path, "w") as file:
            file.write(output)

        print(f"Saved: {file_path}")

    else:
        print(f"Failed to retrieve {case_url}. Status code: {response.status_code}")

print("Scraping complete! All case data saved in 'case_data' folder.")

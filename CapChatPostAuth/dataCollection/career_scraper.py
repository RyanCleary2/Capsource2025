import requests
from bs4 import BeautifulSoup
import json
import time

# Headers to mimic a browser visit
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36"
}

# Dictionary to store collected career data
career_data = {}

### === (1) Scrape O*NET Online === ###
def scrape_onet():
    url = "https://www.onetonline.org/find/quick?s=software"
    response = requests.get(url, headers=HEADERS)
    
    if response.status_code == 200:
        soup = BeautifulSoup(response.text, "html.parser")
        
        for job_link in soup.select(".career_title a"):
            job_title = job_link.text.strip()
            job_url = "https://www.onetonline.org" + job_link.get("href")

            # Scrape job details
            job_resp = requests.get(job_url, headers=HEADERS)
            job_soup = BeautifulSoup(job_resp.text, "html.parser")

            # Extract relevant details
            skills = [li.text.strip() for li in job_soup.select(".skills-list li")]
            education = [edu.text.strip() for edu in job_soup.select(".education-list li")]
            
            career_data[job_title] = {
                "source": "O*NET",
                "skills": skills,
                "education": education,
                "link": job_url
            }

            time.sleep(1)  # Avoid rapid requests

    else:
        print(f"Failed to scrape O*NET. Status: {response.status_code}")


### === (2) Scrape BLS Occupational Outlook Handbook === ###
def scrape_bls():
    base_url = "https://www.bls.gov/ooh/computer-and-information-technology/software-developers.htm"
    response = requests.get(base_url, headers=HEADERS)
    
    if response.status_code == 200:
        soup = BeautifulSoup(response.text, "html.parser")

        # Extract job title and median salary
        job_title = soup.find("h1").text.strip()
        salary_section = soup.find("p", class_="highlight-text")
        median_salary = salary_section.text.strip() if salary_section else "N/A"

        # Add to dictionary
        career_data[job_title] = {
            "source": "BLS",
            "median_salary": median_salary,
            "link": base_url
        }

    else:
        print(f"Failed to scrape BLS. Status: {response.status_code}")


### === (3) Scrape My Next Move === ###
def scrape_my_next_move():
    url = "https://www.mynextmove.org/find/browse?c=0"
    response = requests.get(url, headers=HEADERS)

    if response.status_code == 200:
        soup = BeautifulSoup(response.text, "html.parser")
        
        for job_link in soup.select(".browse a"):
            job_title = job_link.text.strip()
            job_url = "https://www.mynextmove.org" + job_link.get("href")

            career_data[job_title] = {
                "source": "My Next Move",
                "link": job_url
            }

            time.sleep(1)  # Avoid too many requests

    else:
        print(f"Failed to scrape My Next Move. Status: {response.status_code}")


### === (4) Run All Scrapers and Save Data === ###
def main():
    print("Scraping O*NET...")
    scrape_onet()

    print("Scraping BLS...")
    scrape_bls()

    print("Scraping My Next Move...")
    scrape_my_next_move()

    # Save the collected data as JSON
    with open("careers.json", "w") as json_file:
        json.dump(career_data, json_file, indent=4)

    print(f"Scraping complete! Data saved to careers.json")


if __name__ == "__main__":
    main()
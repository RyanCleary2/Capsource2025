from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
import json
import time

def scrape_career_data():
    # Setup Selenium WebDriver
    options = Options()
    options.add_argument("--headless")  # Run in headless mode
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
    
    url = "https://www.onetonline.org"  # Example site for career data
    driver.get(url)
    time.sleep(3)  # Wait for JavaScript to load
    
    career_data = []
    
    # Locate career categories
    career_sections = driver.find_elements(By.CLASS_NAME, "career-group")
    for section in career_sections:
        category = section.find_element(By.TAG_NAME, "h2").text.strip()
        careers = section.find_elements(By.TAG_NAME, "a")
        
        for career in careers:
            career_title = career.text.strip()
            career_link = career.get_attribute("href")
            career_data.append({"category": category, "title": career_title, "link": career_link})
    
    driver.quit()
    
    # Save data to JSON file
    with open("career_data.json", "w", encoding="utf-8") as f:
        json.dump(career_data, f, indent=4, ensure_ascii=False)
    
    print(f"Scraped {len(career_data)} careers and saved to career_data.json")

# Run the scraper
scrape_career_data()
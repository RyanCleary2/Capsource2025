import requests
from bs4 import BeautifulSoup

# URL of the page to scrape
url = "https://capsource.app/libraries?default=true"

# Headers to mimic a browser visit (optional, but helps avoid blocks)
headers = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36"
}

# Fetch the webpage content
response = requests.get(url, headers=headers)

# Check if the request was successful
if response.status_code == 200:
    soup = BeautifulSoup(response.text, "html.parser")

    # Find all 'a' tags that contain case links
    case_links = []
    for a_tag in soup.find_all("a", class_="btn btn-primary text-white"):
        link = a_tag.get("href")
        if link and "cases/library" in link:  # Ensure it's a case link
            full_link = f"{link}"
            case_links.append(full_link)

    # Save links to a text file
    with open("case_links.txt", "w") as file:
        for link in case_links:
            file.write(link + "\n")

    print(f"Saved {len(case_links)} case links to case_links.txt")

else:
    print(f"Failed to retrieve webpage. Status code: {response.status_code}")


# CapSource AI Project Generator

## Overview
The CapSource AI Project Generator is a Flask-based web application that leverages OpenAI's API to generate detailed project scopes for educational and industry-relevant projects. Users input a company website URL and a goal statement, and the application produces a structured project scope, including sections like Challenge/Opportunity, Action Items, Milestones, and more. This tool aims to streamline project creation for educators, students, and organizations.

## Features
- **AI-Powered Scope Generation**: Uses OpenAI's gpt-4o-mini model to generate comprehensive project scopes.
- **Responsive UI**: A clean, modern interface with mobile-friendly design.
- **Error Handling**: Basic validation and error logging for debugging.
- **Extensible Structure**: Modular Flask app with separate templates for input (index.html) and results (result.html).

## Project Structure
```
CapSource-AI-Project-Generator/
├── static/
│   └── logo.png         # Logo image for the header
├── templates/
│   ├── index.html      # Input form page
│   └── result.html     # Results display page
├── .env                # Environment variables (not tracked in git)
├── app.py             # Main Flask application
├── requirements.txt    # Python dependencies
└── README.md          # This file
```

## Prerequisites
- Python 3.8+
- Git
- A valid OpenAI API key

## Setup Instructions

### Clone the Repository
```bash
git clone <repository-url>
cd CapSource-AI-Project-Generator
```

### Set Up a Virtual Environment
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### Install Dependencies
Create a `requirements.txt` file with the following content:
```
flask==2.3.3
flask-cors==4.0.0
python-dotenv==1.0.0
openai==1.10.0
```
Then install:
```bash
pip install -r requirements.txt
```

### Configure Environment Variables
Create a `.env` file in the root directory with your OpenAI API key:
```
OPENAI_API_KEY=your-api-key-here
```
Ensure `.env` is added to `.gitignore` to keep the key secure.

### Add Static Assets
Place a `logo.png` file in the `static/` directory for the header logo. If not available, update the `url_for('static', filename='logo.png')` references in `index.html` and `result.html` to a placeholder or remove them.

### Run the Application
```bash
python app.py
```
The app will start on http://127.0.0.1:5000 in debug mode.

## Usage
- **Access the App**: Open a browser and navigate to http://127.0.0.1:5000.
- **Input Details**: On the homepage (`index.html`), enter:
  - A company website URL (required).
  - A background/goal statement (required).
  - Optional fields: Project Owner, Industry, Project Type (currently unused in scope generation).
- **Generate Project**: Click "Generate Project" to submit the form.
- **View Results**: If successful, the app redirects to the results page (`result.html`) displaying the AI-generated project scope. If an error occurs, it returns to the input page with an error message.

## Technical Details

### Backend: 
- Flask handles routing (`/` for input, `/generate_project` for processing).
- OpenAI API integration in `generate_project_scope()` function.
- Error handling for missing inputs and API failures with debug logging.

### Frontend: 
- `index.html`: Form for user input with CSS styling.
- `result.html`: Displays the generated scope with navigation buttons ("Back to Generator" and "Download PDF" - latter not yet functional).
- **Styling**: Custom CSS with variables (:root) for theming, responsive design via media queries.

## Current Limitations
- **Download PDF**: The "Download PDF" button in `result.html` is styled but lacks backend functionality.
- **Optional Fields**: Industry and Project Type fields in `index.html` are not yet utilized in the project scope generation.
- **Error Feedback**: Limited user-facing error messages; relies on server logs for detailed debugging.
- **Security**: No authentication or rate limiting implemented yet.

## Development Notes
- **Debugging**: Debug logs are printed to the console (e.g., API requests, responses, errors). Consider integrating a proper logging framework (e.g., Python’s logging module) for production.
- **Extending Functionality**: 
  - Add PDF generation using a library like reportlab or weasyprint.
  - Incorporate optional form fields into the prompt for more tailored scopes.
  - Implement user authentication and session management.
- **Testing**: No unit tests are currently included. Consider adding tests with pytest for API calls and routing.

## Deployment
For production:
- Set `debug=False` in `app.run()` or use a WSGI server like Gunicorn:
```bash
gunicorn --bind 0.0.0.0:5000 app:app
```
- Host static files via a web server (e.g., Nginx) or a CDN.
- Secure the API key using environment variables on the server (not `.env` in git).
- Consider a reverse proxy (e.g., Nginx) and HTTPS setup.

## Contributing
- Submit pull requests with detailed descriptions.
- Follow PEP 8 for Python code style.
- Update this README with new features or changes.

## Contact
For questions, reach out to the Engineering team lead or open an issue in the repository.

**Notes**: This README assumes the team is familiar with Python, Flask, and basic web development workflows. It includes actionable setup steps and highlights areas for improvement (e.g., PDF download, testing). You may need to adjust placeholders like `<repository-url>` or add team-specific contact info.

If additional features (e.g., PDF generation) are implemented later, update the README accordingly.

## Overview
The CapSource AI Project Generator is a Flask-based web application designed to help educators, students, and organizations quickly generate comprehensive project scopes and innovative project ideas. Leveraging OpenAI's API, the application produces detailed project scopes based on a company website and a user-provided goal statement, and it can also generate concise project ideas from selected topics. This updated version features improved error handling, refined prompt structures, and dedicated endpoints for both project ideas and full scope generation.

## Features
- **AI-Powered Project Idea Generation**: Generate 3-5 concise project ideas (each with a title and brief description) based on a company’s website and selected topics.
- **AI-Powered Scope Generation**: Create detailed project scopes including:
  - **Project Title**
  - **Challenge/Opportunity** (150–200 words)
  - **Action Items** (bulleted list)
  - **Measuring Success** (bulleted list)
  - **Topics Covered** (bulleted list)
  - **Milestones 1–5** (each with title, guiding questions, and suggested deliverables)
  - **Helpful Public Resources** (links with one-line descriptions)
- **Generate Scope From Idea**: Convert a selected project idea into a full project scope.
- **Responsive UI**: Clean and mobile-friendly interface using Flask templates.
- **Error Handling**: Basic validation with console logs for API issues and input errors.
- **Extensible Architecture**: Modular design for easy integration of future enhancements (e.g., PDF download functionality, additional form fields, user authentication).

## Project Structure
\`\`\`
CapSource-AI-Project-Generator/
├── static/
│   └── logo.png             # Header/logo image
├── templates/
│   ├── index.html           # Home page with input form
│   └── result.html          # Results page to display generated content
├── .env                     # Environment variables (API keys, etc.) (not tracked in version control)
├── app.py                   # Main Flask application
├── requirements.txt         # Python dependencies
└── README.md                # This file (updated)
\`\`\`

## Prerequisites
- Python 3.8+
- Git
- A valid OpenAI API key

## Setup Instructions

### 1. Clone the Repository
\`\`\`bash
git clone <repository-url>
cd CapSource-AI-Project-Generator
\`\`\`

### 2. Set Up a Virtual Environment
\`\`\`bash
python -m venv venv
# On Unix-based systems:
source venv/bin/activate
# On Windows:
venv\Scripts\activate
\`\`\`

### 3. Install Dependencies
Create (or update) the \`requirements.txt\` file with the following content:
\`\`\`
flask==2.3.3
flask-cors==4.0.0
python-dotenv==1.0.0
openai==1.10.0
\`\`\`
Then install the dependencies:
\`\`\`bash
pip install -r requirements.txt
\`\`\`

### 4. Configure Environment Variables
Create a \`.env\` file in the project root with your OpenAI API key:
\`\`\`env
OPENAI_API_KEY=your-api-key-here
\`\`\`
*Tip: Ensure that your \`.env\` file is added to \`.gitignore\` to protect your API key.*

### 5. Add Static Assets
Place your \`logo.png\` file in the \`static/\` directory. If you do not have a logo, update the image references in the HTML templates or remove them.

## Running the Application
Start the Flask server:
\`\`\`bash
python app.py
\`\`\`
Visit [http://127.0.0.1:5000](http://127.0.0.1:5000) in your browser.

## Usage
1. **Access the App**: Open your browser and navigate to [http://127.0.0.1:5000](http://127.0.0.1:5000).
2. **Input Data**:
   - **For Project Ideas**: Enter a company website URL and select one or more topics.
   - **For Project Scope**: Enter a company website URL and provide a goal or background statement.
3. **Generate Content**:
   - Click **Generate Project** to either see a list of project ideas or a detailed project scope.
   - Use the **Generate Scope From Idea** option to convert a chosen project idea into a full project scope.
4. **Download PDF**: The "Download PDF" button on the result page is styled but not yet functional. Future releases may include PDF generation using libraries like ReportLab or WeasyPrint.

## Technical Details

### Backend (Python/Flask)
- **Endpoints**:
  - \`/\`: Homepage (input form)
  - \`/generate_project\`: Processes form submissions and generates project ideas or scope.
  - \`/generate_scope_from_idea\`: Converts a selected project idea into a full project scope.
- **API Integration**: Uses the OpenAI GPT-4O-mini model to generate text.
- **Error Handling**: Logs errors and missing inputs, returning user-friendly messages on the UI.

### Frontend (HTML/CSS)
- **Templates**:
  - \`index.html\`: Form for user input.
  - \`result.html\`: Displays the generated project scope or ideas.
- **Design**: Responsive layout with custom CSS and media queries for mobile support.

## Current Limitations & Future Enhancements
- **Download PDF Feature**: Currently, the "Download PDF" option is a placeholder. Future updates will add this functionality.
- **Additional Form Fields**: Optional fields such as Industry and Project Type are not integrated into the generation prompts.
- **Error Feedback**: Error messages on the user interface are minimal; further improvements are planned.
- **Security**: Authentication and rate limiting are not implemented yet.
- **Testing**: No unit tests are currently in place; consider integrating tests (e.g., using pytest) for robustness.

## Deployment
For production, consider the following:
- Set \`debug=False\` in production or use a WSGI server like Gunicorn:
  \`\`\`bash
  gunicorn --bind 0.0.0.0:5000 app:app
  \`\`\`
- Use a web server or CDN for static file hosting.
- Secure API keys using environment variables (avoid storing them in source code).
- Implement HTTPS and consider a reverse proxy (e.g., Nginx) for improved security.

## Contributing
Contributions are welcome! When contributing, please:
- Fork the repository and create a new branch for your changes.
- Follow PEP 8 guidelines for Python code.
- Update this README as necessary.
- Provide detailed pull request descriptions.

## Contact
For any questions or feedback, please contact the project maintainer or open an issue in the repository.`;

      // Create a Blob object from the README content
      const blob = new Blob([readmeContent], { type: 'text/markdown' });
      // Create an object URL for the Blob
      const url = URL.createObjectURL(blob);
      document.getElementById("downloadLink").href = url;
    </script>
  </body>
</html>
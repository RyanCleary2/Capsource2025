# CapSource Projects

This repository hosts five complementary AI-powered projects designed to empower students, educators, and industry professionals through intelligent career coaching, automated profile generation, project ideation, case study creation, and mentorship guidance:

- **CapChat** – An AI Career & Project Coach for CapSource
- **CapSource AI Project Generator** – A Rails 8 web application that creates student project ideas and scopes
- **CapSource AI Profile Generator** – Automated profile generation from resumes and websites using AI
- **AI Case Generator** – AI-powered case study generator for CapSource
- **AI Mentoring** – AI-driven mentorship matching and guidance system

---

## Table of Contents

1. [CapChat](#capchat)
   - [Overview](#overview)
   - [Features](#features)
   - [Architecture](#architecture)
   - [Code Highlights](#code-highlights)
   - [Setup & Usage](#setup--usage)
   - [Known Issues](#known-issues)

2. [CapSource AI Project Generator](#capsource-ai-project-generator)
   - [Overview](#overview-1)
   - [Features](#features-1)
   - [Tech Stack](#tech-stack)
   - [Prerequisites](#prerequisites)
   - [Installation & Running](#installation--running)
   - [Project Structure](#project-structure)
   - [Routes & Endpoints](#routes--endpoints)
   - [AI Integration](#ai-integration)
   - [Testing](#testing)
   - [Deployment](#deployment)
   - [Contributing](#contributing)
   - [License](#license)

3. [CapSource AI Profile Generator](#capsource-ai-profile-generator)
   - [Overview](#overview-2)
   - [Features](#features-2)
   - [Tech Stack](#tech-stack-1)
   - [Architecture](#architecture-1)
   - [Prerequisites](#prerequisites-1)
   - [Installation & Running](#installation--running-1)
   - [Routes & Endpoints](#routes--endpoints-1)
   - [AI Integration](#ai-integration-1)
   - [Background Jobs](#background-jobs)
   - [Deployment](#deployment-1)
   - [Live Application](#live-application)

4. [AI Case Generator](#ai-case-generator)
   - [Overview](#overview-3)
   - [Status](#status)

5. [AI Mentoring](#ai-mentoring)
   - [Overview](#overview-4)
   - [Status](#status-1)

---

## CapChat

### Overview
CapChat is a conversational AI assistant built for CapSource to guide users through career opportunities, real-world projects, and mentorship pathways. It leverages natural language understanding, context awareness, and feedback loops to deliver personalized, role-specific assistance.

### Features
- **Contextual Understanding**
  - Intent recognition with OpenAI Embeddings
  - Named Entity Recognition (NER) via spaCy
  - Spelling correction using TextBlob
  - Sentiment analysis to adjust response tone
  - Clarifying prompts for ambiguous input
  - Smart query rewriting for precision

- **Role-Based Personalization**
  - **Students**: project discovery, internship guidance, mentorship
  - **Academic Partners**: curriculum integration, course design support
  - **Industry Professionals**: talent sourcing, project collaboration

- **Memory Handling**
  - Session-based (PostgreSQL) and long-term (MongoDB) memory
  - Embeds past interactions into follow-up prompts

- **Retrieval-Augmented Generation (RAG)**
  - Combines GPT-4o with indexed CapSource knowledge
  - Vector similarity search over FAQs, project guides, and user data

- **Feedback & Optimization**
  - Explicit feedback (thumbs up/down + comments)
  - Implicit feedback (drop-off detection)
  - A/B testing of prompt strategies
  - Automated feedback ingestion for iterative improvements

### Architecture
```
User Input
   │
   ▼
Preprocessing → Intent & NER → Memory Lookup
   │                    ↘
   └── RAG: GPT-4o + Context Chunks (Role + History + Data)
               ↓
     Response Generation & Clarification
               ↓
        Feedback Collection (Explicit + Implicit)
```

### Code Highlights
- **`ragFirstDraft.py`** implements the end-to-end pipeline:
  - Text cleaning, lemmatization, and spelling correction
  - Embedding-based intent detection (text-embedding-ada-002)
  - Vague input detection and fallback logic
  - Named Entity Extraction with spaCy
  - Sentiment classification via TextBlob
  - `process_user_input()` orchestrates the flow

- **Frontend** (`capchatTest.html`):
  - Responsive chat widget with role selector
  - Dynamic message rendering
  - Minimal CSS layout with gradient headers

### Setup & Usage
**Prerequisites**:
- Python 3.8+
- OpenAI API key
- PostgreSQL (session memory)
- MongoDB (profile memory)
- Libraries: `openai`, `spacy`, `textblob`, `scikit-learn`, `numpy`

```bash
pip install openai spacy textblob numpy scikit-learn
python -m textblob.download_corpora
python -m spacy download en_core_web_sm
```

**Run the pipeline**:
```python
from ragFirstDraft import process_user_input
response = process_user_input("I need help with data science projects")
print(response)
```

### Known Issues
- Abrupt terminations in certain conversation flows
- Incorrect link redirects (e.g., capstonesource.com)
- Premature contact follow-up messages

Refer to `Train AI chatbot.docx` for details.

---

## CapSource AI Project Generator

### Overview
A Rails 8 web application that uses OpenAI's GPT-4o to generate customized student project ideas and full project scopes based on a company website or selected topics.

### Features
- **Project Ideas**: Generates 3–5 concise project ideas per topic
- **Project Scope**: Produces detailed outlines (title, challenge, milestones, resources)
- **Dynamic Forms**: Toggle between ideas and scope modes with live updates
- **Clean UI**: Responsive CSS design via Propshaft & Importmap
- **CORS Enabled**: Rack-CORS for headless front-end use

### Tech Stack
- **Ruby** 3.2.2 (rbenv)
- **Rails** 8.0.2
- **JavaScript** (ES6, importmap-rails)
- **CSS** (custom, no frameworks)
- **OpenAI GPT-4o** (`ruby-openai` gem)
- **Propshaft** asset pipeline
- **SQLite3** (dev/test), **PostgreSQL** (prod)
- **Rack-CORS** for cross-origin

### Prerequisites
- macOS/Linux
- Ruby version manager (rbenv/RVM)
- PostgreSQL (optional, for production)
- `HOME` directory write permissions

### Installation & Running
```bash
git clone https://github.com/your_org/capsource-generator.git
cd capsource-generator
bundle install
```

**Environment**:
```bash
# create .env with:
OPENAI_API_KEY=sk-...
```

**Database** (optional):
```bash
brew install postgresql
brew services start postgresql
rails db:create db:migrate
```

**Start server**:
```bash
bin/rails server -b 127.0.0.1 -p 3000
# browse to http://localhost:3000
```

### Project Structure
```
app/
  controllers/projects_controller.rb   # form handling & OpenAI calls
  views/projects/
    ├ index.html.erb                   # input form
    └ result.html.erb                  # output display
  assets/                              # Propshaft-managed CSS & JS
config/
  initializers/
    ├ cors.rb                          # Rack-CORS config
    └ openai.rb                        # OpenAI client setup
  routes.rb                            # endpoints
Gemfile                                # dependencies
.env (gitignored)                      # local env vars
README.md                              # this file
```

### Routes & Endpoints
| Verb | Path                    | Controller#Action           | Purpose                          |
|------|-------------------------|-----------------------------|----------------------------------|
| GET  | `/`                     | `projects#index`           | Show generator form              |
| POST | `/generate_project`     | `projects#generate_project`| Generate project ideas           |
| POST | `/generate_scope_from_idea` | `projects#generate_scope_from_idea` | Build full scope from idea |

### AI Integration
```ruby
client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
response = client.chat(
  parameters: {
    model:       "gpt-4o-mini",
    messages:    [{ role: "user", content: prompt }],
    max_tokens:  1000,
    temperature: 0.7
  }
)
```
Helper methods in `ProjectsController`:
- `generate_project_ideas`
- `generate_project_scope`

### Testing
No automated tests yet. Recommended:
- **RSpec** for unit/controller specs
- **VCR/Webmock** for API recording
- **Capybara** for end-to-end flows

### Deployment
1. Ensure `OPENAI_API_KEY` is set
2. Use PostgreSQL in production (`pg` gem)
3. Precompile assets:
   ```bash
   RAILS_ENV=production bin/rails assets:precompile
   ```
4. Serve behind nginx/Passenger

### Contributing
1. Fork the repo
2. `git checkout -b feat/awesome`
3. `git commit -am "Add feature"`
4. Push & open a PR

Please follow existing style and add tests for new behavior.

### License
MIT © CapSource Team

---

## CapSource AI Profile Generator

### Overview
A Rails 8 web application that automates the creation of student and organization profiles using AI. The application can parse resume PDFs to generate student profiles and scrape website URLs to create organization profiles, using OpenAI's GPT-4o-mini for intelligent data extraction and enhancement.

### Features
- **Resume Parsing**: Upload PDF resumes and automatically extract structured profile data
- **Website Scraping**: Generate organization profiles from company website URLs
- **AI Enhancement**: Uses OpenAI GPT-4o-mini to intelligently parse and structure information
- **Background Processing**: Solid Queue for handling time-intensive AI operations
- **Profile Editing**: Review and edit AI-generated profiles before saving
- **Dual Profile Types**: Supports both student profiles and organization profiles
- **Modern Rails Stack**: Built with Rails 8 leveraging the latest framework features

### Tech Stack
- **Ruby** 3.2+ (rbenv/RVM)
- **Rails** 8.0+
- **OpenAI GPT-4o-mini** (via `ruby-openai` gem)
- **Solid Queue** for background job processing
- **PDF Processing** for resume parsing
- **Web Scraping** libraries for website content extraction
- **PostgreSQL** (production), **SQLite3** (dev/test)
- **Propshaft** asset pipeline

### Architecture
```
User Input (PDF/URL)
   │
   ▼
Upload Handler → Background Job Queue (Solid Queue)
   │
   ▼
PDF Parser / Web Scraper
   │
   ▼
AI Processing (GPT-4o-mini)
   │
   ▼
Structured Profile Data → Review & Edit Interface
   │
   ▼
Profile Storage
```

### Prerequisites
- Ruby 3.2+
- Rails 8.0+
- OpenAI API key
- PostgreSQL (for production)
- PDF processing libraries
- Background job processor (Solid Queue)

### Installation & Running
```bash
git clone https://github.com/your_org/capsource-profile-generator.git
cd capsource-profile-generator
bundle install
```

**Environment**:
```bash
# create .env with:
OPENAI_API_KEY=sk-...
```

**Database setup**:
```bash
rails db:create db:migrate
```

**Start server and background jobs**:
```bash
# Terminal 1: Rails server
bin/rails server

# Terminal 2: Solid Queue worker
bin/jobs
```

### Routes & Endpoints
| Verb | Path                    | Controller#Action              | Purpose                           |
|------|-------------------------|--------------------------------|-----------------------------------|
| GET  | `/students/new`         | `students#new`                | Upload resume form                |
| POST | `/students`             | `students#create`             | Process resume and generate profile |
| GET  | `/students/:id/edit`    | `students#edit`               | Edit generated student profile    |
| GET  | `/organizations/new`    | `organizations#new`           | Enter website URL form            |
| POST | `/organizations`        | `organizations#create`        | Scrape and generate org profile   |
| GET  | `/organizations/:id/edit` | `organizations#edit`        | Edit generated organization profile |

### AI Integration
```ruby
client = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))

# Resume parsing prompt
response = client.chat(
  parameters: {
    model: "gpt-4o-mini",
    messages: [
      { role: "system", content: "Extract structured profile data from this resume..." },
      { role: "user", content: resume_text }
    ],
    temperature: 0.3
  }
)

# Website scraping prompt
response = client.chat(
  parameters: {
    model: "gpt-4o-mini",
    messages: [
      { role: "system", content: "Extract company information from this website..." },
      { role: "user", content: website_content }
    ],
    temperature: 0.3
  }
)
```

### Background Jobs
The application uses **Solid Queue** for processing:
- PDF text extraction
- Website content scraping
- AI API calls to OpenAI
- Profile data structuring

Jobs are monitored through the Solid Queue dashboard and processed asynchronously to maintain responsive user experience.

### Deployment
The application is deployed on **Google Cloud Run**:
- Container-based deployment
- Automatic scaling
- Integrated with Cloud SQL (PostgreSQL)
- Environment variables managed through Cloud Run secrets

### Live Application
**Production URL**: https://capsource-profile-builder-493243725919.us-central1.run.app

Visit the live application to:
- Generate student profiles from resume PDFs
- Create organization profiles from website URLs
- Experience AI-powered profile generation in action

---

## AI Case Generator

### Overview
AI-powered case study generator for CapSource that creates comprehensive case studies for student projects and industry collaborations.

### Status
[To be documented]

Documentation for this tool is currently in progress. This section will be updated with:
- Detailed features and capabilities
- Technical architecture
- Setup and installation instructions
- API endpoints and usage examples
- Deployment information

---

## AI Mentoring

### Overview
AI-driven mentorship matching and guidance system that connects students with appropriate mentors and provides intelligent mentorship recommendations.

### Status
[To be documented]

Documentation for this tool is currently in progress. This section will be updated with:
- Matching algorithm details
- Mentorship guidance features
- Technical implementation
- Setup and configuration
- Integration with other CapSource tools

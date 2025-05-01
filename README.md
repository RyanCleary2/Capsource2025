# CapSource Projects

This repository hosts two complementary projects designed to empower students, educators, and industry professionals through AI-driven career coaching and customized project generation:

- **CapChat** – An AI Career & Project Coach for CapSource
- **CapSource AI Project Generator** – A Rails 8 web application that creates student project ideas and scopes

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
- Python 3.8+
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
A Rails 8 web application that uses OpenAI’s GPT-4o to generate customized student project ideas and full project scopes based on a company website or selected topics.

### Features
- **Project Ideas**: Generates 3–5 concise project ideas per topic
- **Project Scope**: Produces detailed outlines (title, challenge, milestones, resources)
- **Dynamic Forms**: Toggle between ideas and scope modes with live updates
- **Clean UI**: Responsive CSS design via Propshaft & Importmap
- **CORS Enabled**: Rack-CORS for headless front-end use

### Tech Stack
- **Ruby** 3.2.2 (rbenv)
- **Rails** 8.0.2
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

# CapSource AI Case Generator 1.0

Last Edited 9/22/2025 - Ryan Cleary 

A Rails 8 web application that uses OpenAI’s GPT-4o to generate customized student cases and full case scopes based on a company website, background goals, or topic selections.

---

## Table of Contents

1. [Features](#features)  
2. [Tech Stack](#tech-stack)  
3. [Prerequisites](#prerequisites)  
4. [Getting Started](#getting-started)  
   1. [Clone & Install](#clone--install)  
   2. [Environment Variables](#environment-variables)  
   3. [Database Setup (optional)](#database-setup-optional)  
5. [Running the App](#running-the-app)  
6. [Project Structure](#project-structure)  
7. [Routes & Endpoints](#routes--endpoints)  
8. [AI Integration](#ai-integration)  
9. [Testing](#testing)  
10. [Deployment](#deployment)  
11. [Contributing](#contributing)  
12. [License](#license)  

---

## Features

- **Case Ideas**: AI-powered generation of 3–5 case ideas based on selected topics.  
- **Case Scope**: Full, structured case outline (title, background/objective, milestones, resources).  
- **Dynamic Forms**: Toggle between scope and ideas modes with live form updates.  
- **Clean UI**: Responsive, modern CSS design using Propshaft & Importmap.  
- **CORS Enabled**: Rack-CORS allows cross-origin requests for headless front-ends.

---

## Tech Stack

- **Ruby** 3.2.2 (via rbenv)  
- **Rails** 8.0.2  
- **JavaScript** (ES6, importmap-rails)  
- **CSS** (custom modern styling, no external frameworks)  
- **OpenAI** GPT-4o API (`ruby-openai` gem)  
- **Propshaft** for asset pipeline  
- **SQLite3** (dev/test) & **PostgreSQL** (prod)  
- **Rack-CORS** for API cross-origin  

---

## Prerequisites

- macOS or Linux  
- [rbenv](https://github.com/rbenv/rbenv) or [RVM] for Ruby version management  
- Homebrew (macOS) for native dependencies  
- PostgreSQL (if using `pg` in development)  

---

## Getting Started

### Clone & Install

```bash
git clone https://github.com/your_org/capsource-case-generator.git
cd capsource-case-generator
bundle install
```

### Environment Variables

Create a `.env` in the project root:

```bash
OPENAI_API_KEY=sk-...
```

Rails (dotenv-rails) will auto-load this.

### Database Setup (optional)

If you plan to use PostgreSQL locally:

```bash
brew install postgresql
brew services start postgresql

# adjust `config/database.yml` if needed
rails db:create db:migrate
```

Otherwise the app runs with SQLite out of the box.

---

## Running the App

```bash
# start the server
bin/rails server -b 127.0.0.1 -p 3000

# visit in browser
http://localhost:3000
```

---

## Project Structure

```
.
├── app/
│   ├── controllers/
│   │   └── cases_controller.rb        # core form handling & OpenAI calls
│   ├── views/
│   │   └── cases/
│   │       ├── index.html.erb         # form + topic checkboxes + toggle JS
│   │       └── result.html.erb        # results view with dynamic rendering
│   └── assets/                        # propshaft-managed CSS & JS
├── config/
│   ├── initializers/
│   │   ├── cors.rb                    # rack-cors config
│   │   └── openai.rb                  # OpenAI client setup
│   └── routes.rb                      # root & POST endpoints
├── Gemfile                            # ruby-openai, rack-cors, dotenv-rails, etc.
├── .env                               # local env vars (gitignore’d)
├── README.md                          # this file
└── ...
```

---

## Routes & Endpoints

| Verb | Path                        | Controller#Action               | Purpose                           |
|------|-----------------------------|---------------------------------|-----------------------------------|
| GET  | `/`                         | `cases#index`                   | Show generator form               |
| POST | `/generate_case`            | `cases#generate_case`           | Generate ideas or full scope      |
| POST | `/generate_scope_from_idea` | `cases#generate_scope_from_idea`| Build full scope from selected idea |

---

## AI Integration

All GPT requests use the `ruby-openai` gem:

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

Helper methods live in `CasesController`:

- `generate_case_ideas`  
- `generate_case_scope`  

---

## Testing

_No automated tests yet._  
Recommend adding:

- **RSpec** for controller/unit tests  
- **VCR** / Webmock to record API interactions  
- **Capybara** for end-to-end form flows  

---

## Deployment

1. Ensure `OPENAI_API_KEY` is set in your host environment.  
2. Use PostgreSQL in production (`pg` gem).  
3. Precompile assets:
   ```bash
   RAILS_ENV=production bin/rails assets:precompile
   ```
4. Start your server behind a reverse proxy (nginx, Passenger, etc.).

---

## Contributing

1. Fork the repo  
2. Create a feature branch: `git checkout -b feat/awesome`  
3. Commit: `git commit -am "Add feature"`  
4. Push & open a PR  

Please follow the existing code style, file naming conventions, and add tests for new behavior.

---

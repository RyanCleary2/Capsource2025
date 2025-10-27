# CapSource JIT Mentoring — Mentorship Plan Generator 1.0

Last Edited: 2025-10-27

This is a lightweight Rails 8 application that uses OpenAI (GPT-4o) to generate personalized mentorship plans for students and early professionals. The app provides a simple form to describe a mentee goal, choose the number of meetings, and generate a structured plan. Results are displayed on a friendly UI and can be edited in-place for quick refinement.

---

## Table of Contents

1. [Features](#features)
2. [Tech Stack](#tech-stack)
3. [Prerequisites](#prerequisites)
4. [Getting Started](#getting-started)
   1. [Clone & Install](#clone--install)
   2. [Environment Variables](#environment-variables)
5. [Running the App](#running-the-app)
6. [Project Structure (JIT_Mentoring)](#project-structure-jit_mentoring)
7. [Routes & Endpoints](#routes--endpoints)
8. [AI Integration](#ai-integration)
9. [Testing](#testing)
10. [Deployment](#deployment)
11. [Contributing](#contributing)

---

## Features

- Generate a full mentorship plan from a concise goal statement.
- Choose the number of meetings (dropdown 1–10) to influence plan granularity.
- Editable results: review and modify the generated plan directly on the results page (enable editing, save/cancel, then select an idea if converting an idea into a scope).
- Clean, responsive UI using Rails view templates and minimal JS (no heavy frontend frameworks).
- Integration with OpenAI for natural, context-aware plans.

---

## Tech Stack

- Ruby 3.x (project uses Ruby 3.2.x in other modules)
- Rails 8.x
- OpenAI via the `ruby-openai` gem
- Propshaft & Importmap for asset handling (minimal JS/CSS builds)
- SQLite3 for development by default (Postgres recommended for production)

---

## Prerequisites

- macOS or Linux
- rbenv or RVM for Ruby version management
- Homebrew (macOS) for native dependencies
- PostgreSQL if you plan to run with `pg` in development/production

---

## Getting Started

### Clone & Install

```bash
git clone <your-repo-url>
cd Capsource2025/JIT_Mentoring
bundle install
```

### Environment Variables

Create a `.env` (or set the environment variables directly) in the JIT_Mentoring directory:

```bash
OPENAI_API_KEY=sk-...
```

The project expects `OPENAI_API_KEY` to be available when making GPT calls.

---

## Running the App

From the `JIT_Mentoring` folder:

```bash
# start the Rails server (zsh)
bin/rails server -b 127.0.0.1 -p 3001

# then open in browser
http://localhost:3001
```

Note: port choice is arbitrary; pick a port that doesn't conflict with other services.

---

## Project Structure (JIT_Mentoring)

```
JIT_Mentoring/
├── app/
│   ├── controllers/
│   │   └── plans_controller.rb      # handles form and OpenAI requests
│   ├── views/
│   │   └── plans/
│   │       ├── index.html.erb       # generator form (goal + number_of_meetings)
│   │       └── result.html.erb      # editable result view
│   └── assets/
├── config/
│   └── routes.rb
├── Gemfile
└── README.md
```

---

## Routes & Endpoints

| Verb | Path | Controller#Action | Purpose |
|------|------|-------------------|---------|
| GET  | `/`  | `plans#index`     | Show mentorship generator form |
| POST | `/generate_mentorship_plan` | `plans#generate_mentorship_plan` | Generate mentorship plan (uses OpenAI) |

The form submits fields including:
- `mentee_goal` (string) — required
- `number_of_meetings` (integer 1–10) — required

The result view exposes an in-browser editing workflow; edits are client-side by default and not persisted to the server unless additional endpoints are added.

---

## AI Integration

The app uses the `ruby-openai` gem to call OpenAI's chat API. Typical usage:

```ruby
client = OpenAI::Client.new(api_key: ENV.fetch('OPENAI_API_KEY'))

prompt = "Given the mentee goal: #{goal} and #{meetings} meetings, create a mentorship plan..."

response = client.chat(
  parameters: {
    model: 'gpt-4o-mini',
    messages: [{ role: 'user', content: prompt }],
    max_tokens: 1000,
    temperature: 0.7
  }
)

generated_text = response.dig('choices', 0, 'message', 'content')&.strip
```

Helper logic is in `PlansController` and builds prompts based on the `mentee_goal` and `number_of_meetings` inputs.

---

## Testing

- No automated tests yet. Recommended additions:
  - RSpec for controller and unit testing
  - VCR / WebMock for recording OpenAI API interactions
  - Capybara for basic end-to-end form flows

---

## Deployment

1. Ensure `OPENAI_API_KEY` is set in your environment on the host.
2. Use PostgreSQL in production (`pg` gem) and update `config/database.yml`.
3. Precompile assets if deploying:

```bash
RAILS_ENV=production bin/rails assets:precompile
```

4. Start the app behind a reverse proxy (nginx, Passenger, etc.) or deploy to a platform that supports Rails apps.

---

## Contributing

1. Fork the repo
2. Create a branch: `git checkout -b feat/mentorship-ui`
3. Commit changes: `git commit -am "Add mentorship feature"`
4. Push & open a pull request

Please follow existing conventions and add tests for any new behavior.

---

If you'd like, I can:

- Add server-side persistence for edited plans (save/load per session or user).
- Add an endpoint to download an edited plan as PDF/DOCX.
- Wire a small integration test (RSpec + VCR) for the OpenAI prompt flow.

Which of these would you like next?


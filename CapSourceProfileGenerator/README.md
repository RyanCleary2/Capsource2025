# CapSource Profile Generator

AI-powered web application for generating comprehensive student and organization profiles by parsing resumes and scraping websites using OpenAI's GPT-4o-mini model.

## Key Features

- **Resume Upload & Parsing**: Upload PDF resumes to automatically extract key information
- **Organization Website Scraping**: Input a URL to gather organization details and create profiles
- **AI Profile Generation**: Uses GPT-4o-mini to enhance and structure profile data
- **Skill Extraction**: Automatically identifies technical and soft skills
- **Real-time Updates**: Dynamic UI with Hotwire Turbo and Stimulus
- **Profile Editing**: Customize AI-generated profiles before saving
- **Background Job Processing**: Efficient handling of large uploads with Solid Queue

## Tech Stack

- **Framework**: Rails 8.0.3
- **Language**: Ruby 3.3+
- **Database**: SQLite 2.1+
- **Frontend**: Hotwire (Turbo & Stimulus), Tailwind CSS
- **PDF Processing**: pdf-reader
- **Web Scraping**: HTTParty, Nokogiri
- **AI**: OpenAI Ruby Gem (GPT-4o-mini)
- **Background Jobs**: Solid Queue
- **Deployment**: Docker, Kamal

## Prerequisites

- Ruby 3.3 or higher
- SQLite3 2.1 or higher
- Node.js 18+
- OpenAI API key ([Get one here](https://platform.openai.com/api-keys))

## Quick Start

1. Create a `.env` file with your OpenAI API key:
   ```bash
   cp .env.example .env
   # Edit .env and add your OPENAI_API_KEY
   ```

2. Run the start script:
   ```bash
   ./start.sh
   ```

3. Visit `http://localhost:3000`

**To restart the server:**
```bash
./restart.sh
```

## Usage

### Student Profiles
1. Navigate to `/students` or click "Create Student Profile"
2. Upload a PDF resume
3. Click "Process Resume"
4. Review and edit the AI-generated profile
5. Click "Save Profile"

### Organization Profiles
1. Navigate to `/organizations` or click "Create Organization Profile"
2. Enter the organization's website URL
3. Click "Process Website"
4. Review and customize the profile
5. Click "Save Profile"

## Deployment

Deploy to Google Cloud Run using:
```bash
./deploy-to-cloud-run.sh
```

**Prerequisites**: Google Cloud CLI (gcloud)

**Production URL**: Will be provided after first deployment

## Environment Variables

| Variable | Required | Notes |
|----------|----------|-------|
| `OPENAI_API_KEY` | Yes | Your OpenAI API key |
| `OPENAI_MODEL` | No | Default: `gpt-4o-mini` |
| `RAILS_ENV` | No | Default: `development` |

## Support

For detailed deployment instructions and additional documentation, see:
- [DEPLOYMENT.md](./DEPLOYMENT.md) for cloud setup
- [CHANGELOG.md](./CHANGELOG.md) for version history

**Last Updated**: November 2025

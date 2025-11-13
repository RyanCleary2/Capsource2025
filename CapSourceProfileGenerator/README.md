# CapSource Profile Generator

AI-powered profile generation tool that creates comprehensive organization and student profiles by intelligently parsing resumes and scraping websites using OpenAI's GPT-4o-mini model. Fully integrated with CapSource's data models and ready for production deployment.

## Overview

CapSource Profile Generator automates the creation of rich, structured profiles for:
- **Organizations** (Companies & Universities) - From website URLs
- **Students/Professionals** - From PDF resumes

The tool leverages advanced AI to extract, enhance, and structure data into CapSource's database schema, ensuring seamless integration with the main CapSource platform.

## Key Features

### Organization Profile Generation
- **Automated Web Scraping**: Extracts data from organization websites
- **AI-Enhanced Descriptions**: Generates comprehensive 4-6 paragraph About sections
- **Smart URL Discovery**: Automatically finds and validates organization website URLs
- **Social Media Extraction**: Intelligently extracts and validates social media links (LinkedIn, Facebook, Twitter, Instagram, YouTube)
- **Metadata Generation**: Creates organization type, employee count, growth stage, and more
- **Tag Association**: Automatically generates and associates development interests, areas of expertise, and skills
- **Similar Organizations**: AI identifies competitor organizations and similar entities
- **Dual Profile Support**: Handles both company and university/school profiles

### Student/Professional Profile Generation
- **Resume Parsing**: Extracts structured data from PDF resumes
- **Educational Background**: Captures degrees, universities, GPAs, honors
- **Professional Experience**: Extracts job history, achievements, and responsibilities
- **Skills Extraction**: Identifies technical skills, soft skills, and languages
- **Profile Enhancement**: AI-generated professional summaries and descriptions

### Technical Features
- **Background Job Processing**: Asynchronous processing with Solid Queue
- **Real-time Status Updates**: Polling-based UI updates during processing
- **Rich Text Support**: Action Text for formatted descriptions and content
- **File Attachments**: Active Storage for logos, banners, and promotional videos
- **Comprehensive Error Handling**: Retry logic with exponential backoff
- **Validation & Data Quality**: URL validation, social media verification, and field sanitization
- **Production-Ready**: Docker support, Kamal deployment, and Cloud Run configuration

## Architecture

### Data Model Integration

Fully integrated with CapSource database schema:

```
Partner (Organization)
├── CompanyDetail (growth_stage, headquarter, etc.)
├── Departments
├── TagResources (polymorphic associations)
│   ├── Topics (category: 0)
│   ├── Industries (category: 1)
│   ├── Domain Experts (category: 7)
│   ├── PD Topics (category: 8)
│   └── Skills (category: 9)
├── Rich Text Fields (Action Text)
│   ├── short_description
│   ├── long_description
│   ├── overview
│   └── tagline
└── Attachments (Active Storage)
    ├── logo
    ├── banner
    └── promo_video

Profile (Student/Professional)
├── User (personal information)
├── EducationalBackgrounds
├── ProfessionalBackgrounds
└── TagResources (Skills)
```

### Service Architecture

Following CapSource's established patterns:

```
Controller → Job (async) → Service → Models

OrganizationsController
  ↓
OrganizationProcessingJob
  ↓
├── OrganizationScraper (web scraping)
└── OpenaiOrganizationEnhancer (AI processing)
    ↓
    Partner + CompanyDetail + Tags + Departments
```

### AI Processing Pipeline

1. **Web Scraping** - Extracts raw data from URLs
2. **AI Enhancement** - OpenAI GPT-4o-mini structures and enriches data
3. **Field Extraction** - Pattern-based parsing of AI responses
4. **Enum Mapping** - Converts AI output to database enum values
5. **Validation** - Cleans and validates URLs, dates, and text fields
6. **Persistence** - Creates database records with proper associations

## Tech Stack

| Component | Technology |
|-----------|-----------|
| **Framework** | Rails 8.0.3 |
| **Language** | Ruby 3.3+ |
| **Database** | SQLite 2.1+ (development), PostgreSQL (production) |
| **Frontend** | Hotwire (Turbo & Stimulus), Tailwind CSS |
| **AI Model** | OpenAI GPT-4o-mini |
| **PDF Processing** | pdf-reader gem |
| **Web Scraping** | HTTParty, Nokogiri |
| **Background Jobs** | Solid Queue |
| **Rich Text** | Action Text (Trix editor) |
| **File Storage** | Active Storage |
| **Deployment** | Docker, Kamal, Google Cloud Run |

## Prerequisites

- Ruby 3.3 or higher
- SQLite3 2.1+ (development)
- Node.js 18+
- OpenAI API key ([Get one here](https://platform.openai.com/api-keys))
- Docker (optional, for deployment)
- Google Cloud SDK (optional, for Cloud Run deployment)

## Installation & Setup

### 1. Clone & Install Dependencies

```bash
cd CapSourceProfileGenerator
bundle install
```

### 2. Configure Environment Variables

Create a `.env` file with your OpenAI API key:

```bash
cp .env.example .env
```

Edit `.env` and add:
```env
OPENAI_API_KEY=sk-proj-your-api-key-here
OPENAI_MODEL=gpt-4o-mini
```

### 3. Setup Database

```bash
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed  # Optional: adds sample data
```

### 4. Start the Application

**Quick Start (recommended):**
```bash
./start.sh
```

**Manual Start:**
```bash
bin/dev  # Starts Rails server + Tailwind CSS watcher
```

**Restart Server:**
```bash
./restart.sh
```

### 5. Access the Application

Visit `http://localhost:3000`

## Usage

### Creating Organization Profiles

1. Navigate to **Organizations** from the home page
2. Enter an organization name or website URL
3. Click **"Generate Profile"**
4. Wait 30-60 seconds for AI processing
5. Review the auto-generated profile
6. Edit any fields as needed
7. Upload logo/banner images (optional)
8. Click **"Save Profile"** to persist to database

**Features Generated:**
- Organization name and metadata
- Comprehensive About section (4-6 paragraphs)
- Tagline and overview
- Social media links (validated)
- Business model and organization type
- Employee count and growth stage
- Development interests, expertise areas, and skills
- Similar organizations
- Departments

### Creating Student Profiles

1. Navigate to **Students/Resumes** from the home page
2. Upload a PDF resume
3. Click **"Process Resume"**
4. Wait for AI enhancement
5. Review extracted information
6. Edit personal details, education, experience
7. Click **"Save Profile"**

**Data Extracted:**
- Personal information (name, email, phone, location)
- Educational background (universities, degrees, GPAs)
- Professional experience (companies, positions, dates)
- Technical skills, soft skills, languages
- Professional summary

## API & Integration

### Background Jobs

All processing happens asynchronously via Solid Queue:

```ruby
# Organization processing
OrganizationProcessingJob.perform_later(url, org_type, cache_key)

# Resume processing
ResumeProcessingJob.perform_later(file_path, user_id)
```

### Status Polling

Check processing status via Rails cache:

```ruby
status = Rails.cache.read("#{cache_key}_status")
# Returns: 'processing', 'completed', or 'failed'

data = Rails.cache.read("#{cache_key}_data")
# Returns: { partner_id:, comprehensive_details:, ... }
```

### OpenAI Integration

Services use OpenAI API with:
- **Model**: GPT-4o-mini (configurable)
- **Temperature**: 0.2 (for consistency)
- **Max Tokens**: 3500
- **Retry Logic**: 3 attempts with exponential backoff
- **Error Handling**: Falls back to basic profiles on failure

## Deployment

### Google Cloud Run

Deploy using the provided script:

```bash
./deploy-to-cloud-run.sh
```

**Prerequisites:**
- Google Cloud account
- `gcloud` CLI installed
- Project ID configured

The script will:
1. Build Docker image
2. Push to Container Registry
3. Deploy to Cloud Run
4. Set environment variables
5. Configure memory (2GB) and CPU (2 cores)

**Environment Variables (Production):**
- `RAILS_MASTER_KEY` - From `config/master.key`
- `OPENAI_API_KEY` - Your OpenAI API key
- `OPENAI_MODEL` - gpt-4o-mini
- `RAILS_LOG_TO_STDOUT` - true
- `RAILS_SERVE_STATIC_FILES` - true

### Docker

Build and run locally:

```bash
docker build -t capsource-profile-generator .
docker run -p 3000:80 \
  -e OPENAI_API_KEY=your-key \
  -e RAILS_MASTER_KEY=your-master-key \
  capsource-profile-generator
```

### Kamal Deployment

Configure in `config/deploy.yml` and deploy:

```bash
kamal setup
kamal deploy
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENAI_API_KEY` | Yes | - | OpenAI API key for GPT-4o-mini |
| `OPENAI_MODEL` | No | gpt-4o-mini | OpenAI model to use |
| `OPENAI_ORGANIZATION_ID` | No | - | OpenAI organization ID (optional) |
| `RAILS_MASTER_KEY` | Yes (prod) | - | Rails encrypted credentials key |
| `RAILS_ENV` | No | development | Rails environment |
| `DATABASE_URL` | No | - | Database connection string (production) |

### AI Prompt Configuration

Prompts are defined in `app/services/openai_organization_enhancer.rb`:
- `company_system_prompt` - System instructions for company profiles
- `university_system_prompt` - System instructions for university profiles
- `build_company_prompt` - Field-by-field company prompt
- `build_university_prompt` - Field-by-field university prompt

### Enum Mappings

Located in models with CapSource-compatible values:

```ruby
# Partner
organization_type: ['For Profit', 'Non Profit', 'Bcorp', ...]
employees_count: ['1-10', '11-50', '51-100', ...]
category: { company: 0, school: 1 }

# CompanyDetail
growth_stage: ['Large Enterprise', 'Established Startup', ...]
```

## Development

### Running Tests

```bash
bin/rails test
```

### Code Quality

```bash
bin/rubocop  # Ruby style checking
bin/brakeman # Security analysis
```

### Database Console

```bash
bin/rails console
```

### Logs

Development logs: `log/development.log`
Production logs: `gcloud run logs read --service=capsource-profile-builder`

## Project Structure

```
CapSourceProfileGenerator/
├── app/
│   ├── controllers/
│   │   ├── organizations_controller.rb
│   │   └── resumes_controller.rb
│   ├── jobs/
│   │   ├── organization_processing_job.rb
│   │   └── resume_processing_job.rb
│   ├── models/
│   │   ├── partner.rb
│   │   ├── company_detail.rb
│   │   ├── profile.rb
│   │   ├── tag.rb
│   │   └── tag_resource.rb
│   ├── services/
│   │   ├── openai_organization_enhancer.rb
│   │   ├── openai_profile_enhancer.rb
│   │   ├── organization_scraper.rb
│   │   ├── resume_parser.rb
│   │   └── concerns/ai_parsing_helpers.rb
│   └── views/
│       ├── organizations/
│       │   ├── index.html.erb
│       │   └── result.html.erb
│       └── resumes/
│           ├── index.html.erb
│           └── result.html.erb
├── db/
│   ├── migrate/
│   └── schema.rb
├── config/
│   ├── deploy.yml (Kamal)
│   └── storage.yml (Active Storage)
├── .env.example
├── Dockerfile
├── deploy-to-cloud-run.sh
└── README.md
```

## Security

### Protected Files (Not in Git)

- `.env` - Contains OpenAI API keys
- `config/master.key` - Rails credentials encryption key
- `*.pem`, `*.key` - Certificate files
- `storage/` - Uploaded files

### Best Practices

- API keys are loaded from environment variables
- Sensitive data is encrypted with Rails credentials
- File uploads are validated and sanitized
- SQL injection protection via ActiveRecord
- XSS protection via Rails helpers
- CSRF tokens on all forms

## Troubleshooting

### OpenAI API Errors

**Error**: `OpenAI::Error: 401 Unauthorized`
- **Fix**: Check your `OPENAI_API_KEY` in `.env`

**Error**: `OpenAI::Error: 429 Rate Limit`
- **Fix**: Wait a few seconds, the job will retry automatically

### Background Job Issues

**Jobs not processing:**
```bash
# Check Solid Queue
bin/rails solid_queue:status

# Restart jobs
./restart.sh
```

### Database Issues

**Migration errors:**
```bash
bin/rails db:drop db:create db:migrate
```

## Contributing

This tool is part of the CapSource platform. For contributions:

1. Follow CapSource coding standards
2. Match existing service/job patterns
3. Update tests for new features
4. Ensure enums match CapSource values
5. Keep data models synchronized with main CapSource schema

## License

Proprietary - CapSource Platform

## Support & Contact

For issues or questions:
- GitHub Issues: https://github.com/RyanCleary2/Capsource2025/issues
- Project maintained by the CapSource development team

**Last Updated**: November 2025

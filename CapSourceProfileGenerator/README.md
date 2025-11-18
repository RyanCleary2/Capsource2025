# CapSource Profile Generator

<div align="center">

**AI-Powered Profile Generation for Organizations and Students**

[![Ruby](https://img.shields.io/badge/Ruby-3.3%2B-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.0.4-red.svg)](https://rubyonrails.org/)
[![OpenAI](https://img.shields.io/badge/OpenAI-GPT--4o--mini-412991.svg)](https://openai.com/)

</div>

---

## 📋 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Demo & Screenshots](#demo--screenshots)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Installation & Setup](#installation--setup)
- [Usage Guide](#usage-guide)
- [API & Integration](#api--integration)
- [Deployment](#deployment)
- [Configuration](#configuration)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Known Issues & Limitations](#known-issues--limitations)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

CapSource Profile Generator is an intelligent, AI-powered profile creation tool that automates the generation of comprehensive, structured profiles for:

🏢 **Organizations** (Companies & Universities) - From website URLs or organization names
👨‍💼 **Students/Professionals** - From PDF resumes

The system leverages OpenAI's GPT-4o-mini to extract, enhance, and structure data directly into CapSource's production database schema, ensuring seamless integration with the main CapSource platform.

### What Makes It Special?

- **Zero Manual Data Entry**: Automatically extracts and structures data from unstructured sources
- **AI-Enhanced Content**: Generates professional descriptions, summaries, and metadata
- **Production-Ready**: Fully integrated with CapSource's actual database models and enums
- **Intelligent URL Discovery**: Automatically finds organization websites (including .edu domains for universities)
- **Real-Time Updates**: Live status polling with instant profile editing
- **Data Quality**: Smart validation, field sanitization, and duplicate prevention

## Key Features

### Organization Profile Generation

✅ **Automated Web Scraping**: Extracts comprehensive data from organization websites
✅ **AI-Enhanced Descriptions**: Generates professional 4-6 paragraph About sections
✅ **Smart URL Discovery**: Automatically finds and validates organization website URLs
  - Special .edu domain support for universities (e.g., "Lehigh University" → lehigh.edu)
  - Fallback to .com/.org for companies
  - Intelligent URL validation and verification

✅ **Social Media Extraction**: Intelligently extracts and validates social media links
  - LinkedIn, Facebook, Twitter, Instagram, YouTube
  - URL validation to prevent field marker leakage
  - Handles "N/A" responses gracefully

✅ **Metadata Generation**: Creates comprehensive organization metadata
  - Organization type (For Profit, Non Profit, Bcorp, etc.)
  - Employee count with proper enum mapping
  - Growth stage and business model
  - Founded year and headquarters location

✅ **Tag Association**: Automatically generates and associates:
  - Development interests (Topics)
  - Industries
  - Professional development topics
  - Domain expertise areas
  - Skills and competencies

✅ **Similar Organizations**: AI identifies competitor organizations and similar entities
✅ **Dual Profile Support**: Handles both company and university/school profiles with type-specific prompts
✅ **Live Editing**: Edit any field in-place without losing AI-generated data

### Student/Professional Profile Generation

✅ **Resume Parsing**: Extracts structured data from PDF resumes using intelligent text analysis
✅ **Educational Background**: Captures degrees, universities, GPAs, honors
  - Automatically links to school organization profiles
  - Proper organization_type mapping (school vs company)

✅ **Professional Experience**: Extracts job history, achievements, and responsibilities
  - Automatically links to company organization profiles
  - Clickable company names that auto-generate organization profiles

✅ **Skills Extraction**: Identifies technical skills, soft skills, and languages
✅ **Profile Enhancement**: AI-generated professional summaries and descriptions
✅ **Instant Save**: Immediate profile updates without 20-second loading delays
✅ **HTML-Safe Editing**: Strip HTML tags from rich text fields during editing

### Technical Features

🔧 **Background Job Processing**: Asynchronous processing with Solid Queue
🔧 **Real-time Status Updates**: Polling-based UI updates during processing with cache management
🔧 **Rich Text Support**: Action Text (Trix) for formatted descriptions and content
🔧 **File Attachments**: Active Storage for logos, banners, and promotional videos
🔧 **Comprehensive Error Handling**: Retry logic with exponential backoff for OpenAI API calls
🔧 **Validation & Data Quality**:
  - URL validation and social media verification
  - Field sanitization to prevent field marker leakage
  - Enum mapping validation
  - HTML tag stripping for clean editing

🔧 **Cache Management**: Preserves comprehensive details (similar organizations) across profile updates
🔧 **Production-Ready**: Docker support, Kamal deployment, and Google Cloud Run configuration

---

## Demo & Screenshots

### Organization Profile Generation

1. **Input**: Enter organization name (e.g., "Comcast Corporation")
2. **Processing**: AI scrapes website and generates comprehensive profile (30-60 seconds)
3. **Review**: View auto-generated profile with all fields populated
4. **Edit**: Click edit mode to modify any field in-place
5. **Save**: Changes save instantly without regenerating the entire profile

### Student Profile Generation

1. **Upload**: Drop PDF resume
2. **Processing**: AI extracts and enhances profile data
3. **Review**: View parsed education, experience, and skills
4. **Edit**: Modify personal details, add missing information
5. **Save**: Instant save with immediate UI update

**Note**: Screenshots can be found in the `docs/` directory (if available)

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

### Common Issues & Solutions

#### 1. Social Media Fields Show Field Markers (e.g., "FACEBOOK:", "TWITTER:")

**Symptom**: LinkedIn field shows "FACEBOOK:", Facebook shows "TWITTER:", etc.

**Root Cause**: OpenAI left fields blank, causing regex to capture next field marker

**Fix**: Already implemented in `app/services/concerns/ai_parsing_helpers.rb:44-47`
- Field extraction now rejects values matching `/^[A-Z_]+:/`
- OpenAI prompts updated to use "N/A" instead of blank lines

#### 2. Wrong URLs for Universities (e.g., "lu.com" instead of "lehigh.edu")

**Symptom**: University URL discovery finds `.com` domains instead of `.edu`

**Root Cause**: URL generation didn't prioritize .edu domains for educational institutions

**Fix**: Already implemented in `app/controllers/organizations_controller.rb:253-285`
- Detects universities by keywords (university, college, school)
- Prioritizes .edu domains for educational institutions
- Extracts core names (e.g., "Lehigh University" → "lehigh")

#### 3. Education Links Create Company Profiles Instead of School Profiles

**Symptom**: Clicking university name in resume creates a company instead of school

**Root Cause**: Missing `organization_type` parameter in education institution links

**Fix**: Already implemented in `app/views/resumes/result.html.erb:353`
```ruby
organization_type: 'school'
```

#### 4. Profile Updates Don't Display After Saving

**Symptom**: "Profile updated successfully!" but changes don't appear in view

**Root Cause**: View keys didn't match controller hash keys

**Fix**: Already implemented in `app/controllers/organizations_controller.rb:385-390`
- Added `"numberOfEmployees"` mapping to `employees_count`
- Added `"hqLocation"` mapping to `address`

#### 5. Similar Organizations Disappear After Profile Edit

**Symptom**: After editing organization profile, "Similar Organizations" section shows empty

**Root Cause**: Cache was overwritten with empty `comprehensive_details` hash

**Fix**: Already implemented in `app/controllers/organizations_controller.rb:206-211`
- Preserves existing comprehensive details when updating cache
- Only updates partner data, not AI-generated comprehensive details

#### 6. Profile Save Shows 20-Second Loading Screen

**Symptom**: Editing profile and clicking save triggers 20-second loading animation

**Root Cause**: Cache status not set to 'completed' after update

**Fix**: Already implemented in `app/controllers/resumes_controller.rb:137-141`
```ruby
Rails.cache.write("#{cache_key}_status", 'completed', expires_in: 1.hour)
```

#### 7. HTML Tags Show in Edit Mode

**Symptom**: Users see `<p>Text</p>` when editing rich text fields

**Root Cause**: ActionText stores content as HTML

**Fix**: Already implemented using `strip_tags()` helper on all rich text edit fields

#### 8. Employee Count Validation Error

**Symptom**: `'1000000' is not a valid employees_count`

**Root Cause**: Text input allowed invalid values for enum field

**Fix**: Changed to dropdown select with only valid enum values in view

---

### OpenAI API Errors

**Error**: `OpenAI::Error: 401 Unauthorized`
- **Fix**: Check your `OPENAI_API_KEY` in `.env`
- Ensure the key starts with `sk-proj-` or `sk-`

**Error**: `OpenAI::Error: 429 Rate Limit`
- **Fix**: Wait a few seconds, the job will retry automatically with exponential backoff
- Check your OpenAI usage limits at https://platform.openai.com/usage

**Error**: `OpenAI::Error: Insufficient quota`
- **Fix**: Add credits to your OpenAI account
- Temporary workaround: Jobs will fail gracefully and save basic profile data

---

### Background Job Issues

**Jobs stuck in "processing" state:**
```bash
# Check Solid Queue status
bin/rails solid_queue:status

# Restart entire application
./restart.sh

# Clear stuck cache entries
bin/rails runner "Rails.cache.clear"
```

**Jobs failing silently:**
```bash
# Check logs for errors
tail -f log/development.log

# Check failed jobs in database
bin/rails console
> SolidQueue::FailedExecution.last(10)
```

---

### Database Issues

**Migration errors:**
```bash
# Reset database (WARNING: deletes all data)
bin/rails db:drop db:create db:migrate db:seed
```

**Association errors:**
- Ensure you're using CapSource's actual tag categories (0=topics, 1=industries, 7=domain_experts, 8=pdtopics, 9=skills)
- Check that TagResource associations are created with proper resource_type ('Partner' or 'Profile')

---

### File Upload Issues

**PDF not parsing:**
- Ensure file is a valid PDF (not a scanned image)
- Check file size is under 10MB
- Try opening PDF in browser to verify it's not corrupted

**Images not uploading:**
- Supported formats: JPG, PNG, GIF
- Max file size: 5MB
- Ensure ActiveStorage is configured properly

---

## Known Issues & Limitations

### Current Limitations

1. **PDF Resumes**: Works best with text-based PDFs. Scanned images or complex layouts may not parse well.

2. **OpenAI Rate Limits**: Free tier has rate limits. For production use, upgrade to paid plan.

3. **Website Scraping**: Some websites block automated scraping. The tool will fall back to basic profile generation.

4. **Organization Name Ambiguity**: Generic names like "Google" may require manual URL entry to ensure correct organization.

5. **Social Media Validation**: Only validates URL format, doesn't check if account actually exists.

6. **Concurrent Processing**: Multiple simultaneous profile generations may slow down due to background job queue.

### Future Enhancements

- [ ] Support for scanned/image-based PDFs using OCR
- [ ] Bulk profile generation from CSV
- [ ] Profile comparison and duplicate detection
- [ ] Export profiles to JSON/CSV
- [ ] Integration with LinkedIn API for direct profile import
- [ ] More robust website scraping with JavaScript rendering
- [ ] Profile quality scoring and completeness metrics

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

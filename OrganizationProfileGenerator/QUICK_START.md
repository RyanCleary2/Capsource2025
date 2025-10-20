# Quick Start Guide

## Get Started in 5 Minutes

### 1. Install Dependencies

```bash
cd OrganizationProfileGenerator
bundle install
```

### 2. Set Up Environment

```bash
cp .env.example .env
# Edit .env and add your OpenAI API key
```

### 3. Create Database & Upload Folders

```bash
rails db:create
rails db:migrate
mkdir -p public/uploads/logos public/uploads/banners
```

### 4. Start the Server

```bash
# Option 1: Use the restart script (recommended)
./.restart

# Option 2: Start manually
rails server
```

**Note:** The `.restart` script will automatically kill any process on port 3000 before starting the server.

### 5. Open Browser

Visit: **http://localhost:3000**

---

## Testing the Application

### Test with a Company

1. Select "Company"
2. Enter URL: `https://www.apple.com`
3. Click "Generate Profile"
4. Wait 10-15 seconds for AI processing
5. View and edit the generated profile

### Test with a University

1. Select "School / University"
2. Enter URL: `https://www.mit.edu`
3. Click "Generate Profile"
4. Wait 10-15 seconds for AI processing
5. View and edit the generated profile

---

## Troubleshooting

### OpenAI API Key Issues

If you get authentication errors:

```bash
# Check if your .env file is loaded
cat .env | grep OPENAI_API_KEY

# Restart the Rails server after adding the API key
```

### Missing Dependencies

```bash
bundle install
rails tailwindcss:build
```

### Database Issues

```bash
rails db:drop
rails db:create
rails db:migrate
```

---

## Key Files

- **Controller**: `app/controllers/organizations_controller.rb`
- **Scraper Service**: `app/services/organization_scraper.rb`
- **AI Service**: `app/services/openai_organization_enhancer.rb`
- **Main View**: `app/views/organizations/index.html.erb`
- **Result View**: `app/views/organizations/result.html.erb`

---

## Next Steps

1. Read the full [README.md](README.md) for detailed documentation
2. Customize the AI prompts in the enhancer service
3. Add additional fields as needed
4. Deploy to production

---

**Need help?** Check the [README.md](README.md) or contact support@capsource.io

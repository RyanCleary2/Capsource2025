# AI-Powered Resume Parser - Rails Edition

An intelligent resume parsing application that extracts and enhances professional profile data from PDF resumes using OpenAI's GPT-4o-mini model, styled with CapSource.io's professional design system.

## Overview

This application uses advanced AI technology to parse PDF resumes and create enhanced professional profiles. Built with Ruby on Rails and powered by OpenAI's GPT-4o-mini, it combines traditional PDF parsing with AI enhancement to deliver accurate, professionally formatted profile data.

## Features

### AI-Powered Processing
- **PDF Resume Upload**: Upload PDF resumes for intelligent processing
- **GPT-4o-mini Enhancement**: Uses OpenAI's latest model for data enhancement
- **Smart Parsing**: Combines traditional parsing with AI analysis
- **Fallback System**: Works with or without OpenAI API key
- **Editable Results**: Edit and save parsed profile information
- **Profile Image Upload**: Upload and manage profile pictures in edit mode

### Extracted & Enhanced Data
- **Personal Information**: Name, email, phone, location, LinkedIn, website
- **Profile Image**: Upload and display professional profile pictures
- **Professional Summary**: AI-generated compelling summary highlighting key strengths
- **Work Experience**: Enhanced job descriptions with quantified achievements
- **Education**: Degree, institution, graduation year, GPA, honors
- **Skills**: Categorized technical, soft skills, and languages
- **Projects**: Key projects with technologies used
- **Certifications**: Professional certifications and awards

### Professional Interface
- **Loading Animation**: Progress indicators with percentage completion
- **Real-time Processing**: Watch AI analyze your resume step-by-step
- **Responsive Design**: Works on desktop and mobile devices
- **Professional Styling**: Clean presentation with CapSource design elements

### CapSource.io Design System
- **Color Palette**: Official CapSource orange (#F7931D), deep purple (#301C2A), and accent colors
- **Typography**: Avenir-Book and Open Sans fonts
- **UI Components**: Custom buttons, cards, and form elements
- **Professional Styling**: Clean, minimal design with strategic white space

## Technology Stack

- **Backend**: Ruby on Rails 8.0.2
- **AI**: OpenAI GPT-4o-mini model
- **PDF Processing**: PDF-reader gem for text extraction
- **Styling**: TailwindCSS with custom CapSource.io theme
- **Server**: Puma web server
- **Environment**: dotenv-rails for configuration

## Prerequisites

- Ruby 3.2.2+
- Rails 8.0.2+
- OpenAI API key (required for AI enhancement)

## Installation & Setup

### 1. Clone the Repository
```bash
git clone <repository-url>
cd resume_ai_parser_rails
```

### 2. Install Dependencies
```bash
bundle install
npm install
```

### 3. Environment Configuration

Copy the example environment file:
```bash
cp .env.example .env
```

Edit `.env` and add your OpenAI API key:
```bash
# OpenAI API Configuration
# Get your API key from: https://platform.openai.com/api-keys
OPENAI_API_KEY=your_openai_api_key_here

# OpenAI Model Configuration
OPENAI_MODEL=gpt-4o-mini
```

### 4. Get OpenAI API Key
- Visit [OpenAI Platform](https://platform.openai.com/api-keys)
- Create an account or sign in
- Generate a new API key
- Add the key to your `.env` file

### 5. Start the Application
```bash
./bin/restart
```

Or manually:
```bash
bundle exec rails server
```

Visit `http://localhost:3000` to access the application.

## 📖 Usage Guide

### Basic Workflow
1. **Upload Resume**: Click "Upload Your Resume" and select a PDF file
2. **AI Processing**: Watch the progress bar as GPT-4o-mini analyzes your resume
3. **Review Results**: View the extracted and enhanced profile data
4. **Edit Information**: Click "Edit" to modify any information
5. **Upload Profile Image**: Add or change profile picture in edit mode
6. **Save Changes**: Click "Save Changes" to update the profile data

### Step-by-Step Demo

#### 1. Home Page
```
┌─────────────────────────────────────────────┐
│ 🎯 Resume Profile Demo                      │
│                                             │
│ [Upload PDF Resume Here]                    │
│ ┌─────────────────────────────────────────┐ │
│ │  📄 Click to upload your resume         │ │
│ │     PDF format only                     │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ [VIEW SAMPLE PROFILE] ← CapSource Orange    │
└─────────────────────────────────────────────┘
```

#### 2. Processing
When you click "View Sample Profile", the system:
- Accepts your PDF file upload
- Displays pre-configured sample profile data
- Shows professional formatting and layout

#### 3. Results Page
```
┌─────────────────────────────────────────────┐
│ 📊 Sample Profile Data                      │
│                                             │
│ 👤 Personal Information                     │
│ ┌──────────┬─────────────────────────────────┐ │
│ │ 📷 [IMG] │ Name: Sarah Johnson             │ │
│ │          │ Email: sarah@email.com          │ │
│ │          │ Phone: 555-123-4567             │ │
│ │          │ Location: SF, CA                │ │
│ │          │ [Edit Profile] [🖼️ Upload]      │ │
│ └──────────┴─────────────────────────────────┘ │
│                                             │
│ 💼 Experience                               │
│ ├─ Senior Software Engineer @ TechCorp (2022-Present) │
│ │  • Improved app performance by 40%       │
│ │  • Led team of 4 developers              │
│ └─ Software Developer @ StartupXYZ (2020-2021) │
│                                             │
│ 🎓 Education                                │
│ └─ B.S. Computer Science - UC Berkeley      │
│                                             │
│ ⚡ Skills                                   │
│ [JavaScript] [React] [Node.js] [Python]    │
│ [Leadership] [Communication] [Teamwork]     │
└─────────────────────────────────────────────┘
```

## CapSource.io Design Implementation

### Color System
```css
Primary: #F7931D (CapSource Orange)
Dark: #301C2A (Deep Purple)
Mauve: #66525f (Muted Purple)
Accent Purple: #921245
Red: #CC3131
Blue: #3353ea
```

### Typography
- **Primary**: Open Sans (professional, readable)
- **Secondary**: Avenir-Book (elegant headers)
- **Line Height**: 1.75 (optimal readability)

### UI Components
- **Buttons**: Rectangular, uppercase text, hover effects
- **Cards**: Clean shadows, professional spacing
- **Form Elements**: Consistent styling with CapSource palette
- **Skills Tags**: Color-coded by category (technical/soft/languages)

## Configuration

### Styling Customization
CapSource colors are configured in the layout:
```javascript
tailwind.config = {
  theme: {
    extend: {
      colors: {
        'capsource-orange': '#F7931D',
        'capsource-dark': '#301C2A',
        // ... other colors
      }
    }
  }
}
```

## Project Structure

```
resume_ai_parser_rails/
├── app/
│   ├── controllers/
│   │   └── resumes_controller.rb              # Main application logic
│   ├── services/
│   │   ├── resume_parser.rb                   # Basic PDF parsing
│   │   └── openai_profile_enhancer.rb         # AI enhancement service
│   ├── views/
│   │   ├── layouts/
│   │   │   └── application.html.erb           # CapSource styling
│   │   └── resumes/
│   │       ├── index.html.erb                 # Upload interface
│   │       └── result.html.erb                # Results page with editing
├── config/
│   └── routes.rb                              # Application routes
├── .env.example                               # Environment variables template
├── Gemfile                                    # Dependencies
└── README.md                                  # This file
```

## API Costs

The application uses OpenAI's GPT-4o-mini model, which is cost-effective:
- **Typical resume processing**: ~$0.01-0.02 per resume
- **Model**: GPT-4o-mini (most cost-effective option)
- **Token limits**: 2000 max tokens to control costs
- **Monitor usage**: [OpenAI Usage Dashboard](https://platform.openai.com/usage)

## Troubleshooting

### Common Issues

1. **OpenAI API Errors**
   - Check your API key is valid and properly set in `.env`
   - Ensure you have sufficient credits in your OpenAI account
   - Verify network connectivity

2. **PDF Parsing Issues**
   - Ensure PDF is text-based (not scanned image)
   - Check file size (recommended max 10MB)
   - Try a different PDF format

3. **Edit Button Not Working**
   - Check browser console for JavaScript errors
   - Ensure all required elements are present
   - Try refreshing the page

4. **No AI Enhancement**
   - Verify `OPENAI_API_KEY` is set in `.env`
   - Check application logs for error messages
   - Application will fall back to basic parsing if AI fails

### Logs

Check application logs for debugging:
```bash
tail -f log/development.log
```

Look for messages like:
- "Profile data enhanced with AI" (success)
- "AI enhancement failed" (error with details)

## Security Features

- CSRF protection enabled
- File type validation (PDF only)
- No permanent file storage

## Error Handling

The application includes basic error handling:
- **Invalid Files**: Redirects with error message
- **Missing Files**: Graceful redirect to upload page

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- **CapSource.io** for design inspiration and color palette
- **Ruby on Rails** community for the excellent framework
- **TailwindCSS** for utility-first styling approach

## Support

For questions or support, please open an issue in the repository or contact the development team.

---

Built with ❤️ using Ruby on Rails and styled with CapSource.io's professional design system.

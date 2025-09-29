# SkillOrganizer - Skills Database Management System

## Overview

Ruby on Rails application for managing and organizing CapSource's skills database with intelligent categorization, progression roadmaps, and a modern interface.

## Key Features

### 🎯 Smart Organization
- **Auto-categorization**: 11 intelligent categories (Programming, Data Analytics, Engineering & CAD, etc.)
- **Skill Progression Roadmaps**: Interactive pathways showing prerequisites, next steps, and related skills
- **Duplicate Detection**: Automatic identification and merge suggestions
- **Hierarchical Structure**: Parent-child relationships and skill levels (Beginner/Intermediate/Advanced)

### 🔍 Advanced Search & Filtering
- Real-time search across 650+ skills
- Multi-filter by category, level, domain, and partner
- Pagination and results summary
- Tag-based skill grouping

### 🎨 Modern Interface
- CapSource design system (purple/orange/teal palette)
- Responsive table layout
- Interactive progression roadmap modals
- Mobile-friendly responsive design

### 📊 Data Quality Tools
- Name normalization and validation
- UTF-8 BOM handling for CSV imports
- Duplicate detection with 651 skills loaded
- Similarity scoring for skill relationships

## Quick Start

```bash
# Install dependencies
bundle install

# Start the server
./bin/restart

# Visit http://localhost:3000
```

## Tech Stack

- **Backend**: Ruby 3.2+, Rails 8.0+
- **Data**: CSV-based with service layer (SkillDataService)
- **Frontend**: ERB templates, Turbo/Stimulus
- **Styling**: Custom CSS with CapSource design tokens

## Key Files

```
app/
├── controllers/skills_controller.rb       # CRUD + roadmap endpoints
├── services/skill_data_service.rb         # CSV processing, categorization, roadmap logic
├── views/skills/
│   ├── index.html.erb                     # Main table + filters + modals
│   ├── show.html.erb                      # Skill details
│   └── new.html.erb                       # Create form (demo mode)
├── assets/stylesheets/skills.css          # CapSource-compliant design
└── javascript/roadmap.js                  # Roadmap modal interactions

config/routes.rb                            # Routes with roadmap endpoint
skillDatabase.csv                           # 650+ skills (UTF-8 BOM)
```

## Core Functionality

### Skill Progression Roadmap
Click "Roadmap" on any skill to see:
- **Prerequisites**: Lower-level skills in the same category (with effort estimates)
- **Next Steps**: Higher-level progression paths (similarity-scored)
- **Related Skills**: Complementary skills across categories

**Algorithm**:
- Similarity scoring (category 40%, domain 20%, tags 30%, name 10%)
- Effort estimation based on level gaps (2-12 weeks)
- Top 3 prerequisites, 4 progressions, 6 related skills

### Data Processing
- **Normalization**: Strips quotes, validates length, titleizes names
- **Categorization**: Keyword-based auto-assignment to 11 categories
- **Tag Generation**: Ecosystem tags (Python, Data Science, CAD Software, etc.)
- **Duplicate Handling**: Case-insensitive name matching

## Routes

```ruby
GET    /skills                          # Index with filters
GET    /skills/:id                      # Show skill details
GET    /skills/:id/roadmap              # Roadmap JSON API
GET    /skills/:id/relationships        # Related skills
GET    /skills/new                      # New skill form (CSV demo mode)
```

## Development

```bash
# Reload cached CSV data
bin/rails runner "SkillDataService.reload!"

# Test roadmap for skill ID 569
bin/rails runner "puts SkillDataService.skill_roadmap(569).inspect"

# Check data quality
bin/rails runner "puts 'Duplicates: ' + SkillDataService.duplicate_count.to_s"
```

## CSV Mode vs Database Mode

**Current**: CSV mode (read-only, fast prototyping)
- Skills loaded from `skillDatabase.csv` on boot
- Create/Edit/Delete disabled (demo notices shown)
- Cached in memory for performance

**Future**: Database mode (full CRUD)
- Migrate to PostgreSQL with `Skill`, `Category`, `SkillRelationship` models
- Enable full editing, partner linking, and advanced relationships

## Design System

### Colors
- **Purple** (`#6B46C1`): Primary actions, headers
- **Orange** (`#F6AD55`): CTAs, current skill badges
- **Teal** (`#4FD1C7`): Roadmap links, secondary accents
- **Grays**: `#F7FAFC` (bg) to `#1A202C` (text)

### Components
- **Skill Badges**: Rounded cards with level, effort, similarity score
- **Roadmap Timeline**: Horizontal path with purple arrows (vertical on mobile)
- **Modal**: Slide-in overlay (1000px max width, 85vh height)
- **Loading Spinner**: Purple gradient animation

## Features in Detail

### 1. Duplicate Detection
- Modal alerts for duplicates (e.g., "3 duplicates of 'Python Programming'")
- Shows IDs and "View" links for manual review
- KPI: Track merge completions

### 2. Filter System
- **Category**: 11 dropdowns (Programming, Engineering, etc.)
- **Level**: Beginner/Intermediate/Advanced
- **Search**: Fuzzy name matching
- **Active Filters**: Badge indicator + "Clear All" button

### 3. Roadmap Modal
- **Loading State**: Spinner with "Loading skill progression..."
- **Current Skill**: Orange gradient badge (center, large)
- **Prerequisites**: Left-to-right timeline (arrows between badges)
- **Next Steps**: 4 progressions with effort estimates (e.g., "4 weeks")
- **Related Skills**: Grid of 6 similar skills (sortable by similarity %)
- **Empty State**: "No progression data available" with map icon

### 4. Responsive Design
- **Desktop**: Multi-column table, horizontal roadmap timelines
- **Tablet**: Stacked filters, scrollable tables
- **Mobile**: Vertical timelines, full-width badges, touch-optimized

## Known Issues & Future Work

### Immediate
- [ ] Partner column empty (populate from CSV or manual entry)
- [ ] Level filtering underutilized (add level badges to table)
- [ ] Some misfits in "Engineering & CAD" (e.g., "Brand Identity Design")

### Phase 2
- [ ] AI-powered categorization refinement
- [ ] Export roadmap as PDF/SVG
- [ ] "Pin to Dashboard" for students
- [ ] Bulk merge tool for duplicates
- [ ] Skill evolution timeline (animate by created_at)
- [ ] Neo4j graph database for advanced relationships

## Accessibility

- WCAG 2.1 AA compliant
- Keyboard navigation (Tab through filters, Enter to open roadmap)
- ARIA labels on inputs and buttons
- High-contrast mode support (4.5:1 minimum)

## Performance

- **Load Time**: 651 skills in <1s (cached)
- **Search**: <100ms response (in-memory filtering)
- **Roadmap**: Lazy-loaded via AJAX (~200ms)

## License

Proprietary software for CapSource ecosystem.

---

**Version**: 1.1.0
**Last Updated**: September 2025
**Features**: Progression Roadmaps, Duplicate Detection, Advanced Filtering
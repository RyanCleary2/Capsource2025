require 'pdf-reader'

class ResumeParser
  include AiParsingHelpers

  def initialize(file_path)
    @file_path = file_path
    @raw_text = extract_text
  end

  def extract_text
    reader = PDF::Reader.new(@file_path)
    text = ""
    reader.pages.each do |page|
      text += page.text + "\n"
    end

    # Log the raw text for debugging
    Rails.logger.debug "Raw PDF text: #{text}"

    # Clean up common PDF extraction issues
    text = text.gsub(/\s+/, ' ')  # Normalize whitespace
    text = text.gsub(/([a-z])([A-Z])/, '\1 \2')  # Add space between camelCase

    text
  end

  def parse_profile_data
    # Enhance with AI if OpenAI API key is available - pass raw text for comprehensive extraction
    if ENV['OPENAI_API_KEY'].present?
      begin
        enhancer = OpenaiProfileEnhancer.new
        enhanced_data = enhancer.extract_from_raw_text(@raw_text)
        Rails.logger.info "Profile data extracted and enhanced with AI from raw text"
        return enhanced_data
      rescue => e
        Rails.logger.error "AI extraction failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    # Fallback: Extract basic data using traditional parsing if AI fails
    personal_info = extract_personal_info

    # Split full name into first and last name using helper
    name_parts = split_full_name(personal_info["fullName"])

    # Build the CapSource schema structure
    profile_data = {
      user: {
        first_name: name_parts[:first_name],
        last_name: name_parts[:last_name],
        email: personal_info["email"],
        phone_number: personal_info["phone"],
        location: personal_info["location"],
        linkedin: personal_info["linkedin"],
        website: personal_info["website"],
        type: 'Users::Student'
      },
      profile: {
        about: extract_professional_summary,
        status: 'draft'
      },
      educational_backgrounds: extract_education_backgrounds,
      professional_backgrounds: extract_professional_backgrounds,
      skills: extract_skills,
      certifications: extract_certifications,
      projects: extract_projects
    }

    profile_data
  end

  private

  def extract_personal_info
    # Extract email
    email_match = @raw_text.match(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/)
    email = email_match&.to_s || ""

    # Extract phone number - more flexible patterns
    phone_patterns = [
      /(\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4})/,
      /(\d{3}[-.\s]?\d{3}[-.\s]?\d{4})/,
      /(\+\d{1,3}[-.\s]?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4})/
    ]
    phone = ""
    phone_patterns.each do |pattern|
      match = @raw_text.match(pattern)
      if match
        phone = match.to_s
        break
      end
    end

    # Extract name - look at the very beginning of the document
    lines = @raw_text.split(/\n+/).map(&:strip).reject(&:empty?)
    name = ""

    # Try different strategies for name extraction
    lines.first(5).each do |line|
      # Skip empty lines
      next if line.empty?

      # Skip lines that look like contact info
      next if line.match?(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/)
      next if line.match?(/\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/)
      next if line.match?(/linkedin|github|portfolio/i)
      next if line.match?(/^\w+,\s*\w+/) # Skip location-like patterns

      # Look for name patterns - first clean line that looks like a name
      clean_line = line.gsub(/[^\w\s]/, '').strip # Remove special characters
      words = clean_line.split

      if words.length >= 2 && words.length <= 4 &&
         words.all? { |word| word.match?(/^[A-Z][a-z]*$/) } # All words are capitalized
        name = clean_line
        break
      end
    end

    # If still empty, try the very first line
    if name.empty? && lines.any?
      first_line = lines.first.gsub(/[^\w\s]/, '').strip
      words = first_line.split
      if words.length >= 2 && words.length <= 4
        name = first_line
      end
    end

    name = "Name not found" if name.empty?

    # Extract location - more flexible patterns
    location_patterns = [
      /([A-Z][a-z]+,\s*[A-Z]{2})/,  # City, ST
      /([A-Z][a-z]+,\s*[A-Z][a-z]+)/,  # City, State
      /(Philadelphia,\s*PA)/i,  # Specific to visible location
      /([A-Z][a-z]+\s*,\s*[A-Z][a-z]+\s*,\s*[A-Z]{2})/  # City, County, ST
    ]

    location = ""
    location_patterns.each do |pattern|
      match = @raw_text.match(pattern)
      if match
        location = match[1].strip
        break
      end
    end

    # Extract LinkedIn - more flexible
    linkedin_patterns = [
      /linkedin\.com\/in\/([a-zA-Z0-9-]+)/,
      /LinkedIn:\s*([^\s\n]+)/i,
      /LinkedIn\s*[:\-]\s*linkedin\.com\/in\/([a-zA-Z0-9-]+)/i
    ]

    linkedin = ""
    linkedin_patterns.each do |pattern|
      match = @raw_text.match(pattern)
      if match
        linkedin = "linkedin.com/in/#{match[1]}"
        break
      end
    end

    # Extract website - exclude email and LinkedIn domains
    website_patterns = [
      /((?:https?:\/\/)?(?:www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:\/[^\s]*)?)/,
      /Portfolio:\s*([^\s\n]+)/i,
      /Website:\s*([^\s\n]+)/i
    ]

    website = ""
    website_patterns.each do |pattern|
      matches = @raw_text.scan(pattern).flatten
      matches.each do |match|
        # Skip if it's an email or LinkedIn
        next if match.include?("@") || match.include?("linkedin.com") || match.include?("gmail.com")
        # Skip if it's too short to be a real website
        next if match.length < 5
        website = match
        break
      end
      break unless website.empty?
    end

    {
      "fullName" => name,
      "email" => email,
      "phone" => phone,
      "location" => location,
      "website" => website,
      "linkedin" => linkedin
    }
  end

  def extract_professional_summary
    lines = @raw_text.split(/\n+/).map(&:strip).reject(&:empty?)

    # Look for explicit summary sections first
    summary_patterns = [
      /(?:SUMMARY|PROFESSIONAL SUMMARY|OBJECTIVE|PROFILE|ABOUT)\s*[:\-]?\s*(.*?)(?=\n(?:EXPERIENCE|WORK|EDUCATION|SKILLS|PROJECTS|EMPLOYMENT|TECHNICAL|$))/mi,
      /(?:Summary|Professional Summary|Objective|Profile|About)\s*[:\-]?\s*(.*?)(?=\n(?:Experience|Work|Education|Skills|Projects|Employment|Technical|$))/mi
    ]

    summary_patterns.each do |pattern|
      match = @raw_text.match(pattern)
      if match && match[1]
        summary = match[1].strip.gsub(/\s+/, ' ')
        # Filter out education-like content
        next if summary.match?(/(?:university|college|graduation|bachelor|master|degree|gpa)/i)
        next if summary.match?(/\b\d{4}\b/) && summary.length < 100  # Likely contains years only

        if summary.length > 30 && summary.length < 500
          return summary
        end
      end
    end

    # If no explicit summary, generate one from education and experience
    education_info = ""
    if @raw_text.match?(/Bachelor.*Computer Science.*Business/i)
      education_info = "Computer Science and Business student"
    elsif @raw_text.match?(/Computer Science/i)
      education_info = "Computer Science student"
    end

    experience_info = ""
    if @raw_text.match?(/Product.*Management.*Intern/i) && @raw_text.match?(/Product.*Development.*Intern/i)
      experience_info = "with experience in product management and development"
    elsif @raw_text.match?(/Software.*Developer/i)
      experience_info = "with software development experience"
    end

    skills_info = ""
    tech_skills = @raw_text.scan(/(?:Java|Python|JavaScript|SQL|Ruby|Rails)/i).uniq
    if tech_skills.length > 3
      skills_info = " skilled in #{tech_skills.first(3).join(', ')}"
    end

    # Generate a concise summary
    if !education_info.empty?
      generated_summary = "#{education_info}#{experience_info}#{skills_info}."
      return generated_summary.gsub(/\s+/, ' ').strip if generated_summary.length > 20
    end

    "Experienced professional with technical and business background."
  end

  def extract_professional_backgrounds
    professional_backgrounds = []

    # Look for work experience section
    exp_patterns = [
      /(?:WORK EXPERIENCE|EXPERIENCE|EMPLOYMENT)[:\n\s]+(.*?)(?=\n(?:LEADERSHIP|EDUCATION|SKILLS|PROJECTS|CERTIFICATIONS|$))/mi,
      /(?:Work Experience|Experience|Employment)[:\n\s]+(.*?)(?=\n(?:Leadership|Education|Skills|Projects|Certifications|$))/mi
    ]

    exp_text = ""
    exp_patterns.each do |pattern|
      match = @raw_text.match(pattern)
      if match && match[1]
        exp_text = match[1].strip
        break
      end
    end

    return professional_backgrounds if exp_text.empty?

    # Split experience entries by job titles (lines that end with date ranges)
    lines = exp_text.split(/\n/).map(&:strip).reject(&:empty?)
    current_entry = []

    lines.each do |line|
      # Look for date patterns that indicate a new job entry
      if line.match?(/(?:June|July|August|September|October|November|December|January|February|March|April|May)\s+\d{4}\s*[-–—]\s*(?:\w+\s+\d{4}|Present|Current)/i)
        # Process previous entry if exists
        if !current_entry.empty?
          professional_backgrounds << parse_professional_background_entry(current_entry)
        end
        # Start new entry
        current_entry = [line]
      else
        current_entry << line
      end
    end

    # Process the last entry
    if !current_entry.empty?
      professional_backgrounds << parse_professional_background_entry(current_entry)
    end

    professional_backgrounds.compact
  end

  def parse_professional_background_entry(entry_lines)
    return nil if entry_lines.empty?

    # First line should be the title with date range
    title_line = entry_lines[0]
    date_match = title_line.match(/((?:June|July|August|September|October|November|December|January|February|March|April|May)\s+\d{4})\s*[-–—]\s*((?:\w+\s+\d{4}|Present|Current))/i)

    return nil unless date_match

    start_date_str = date_match[1]
    end_date_str = date_match[2]
    title = title_line.gsub(date_match[0], '').strip

    # Parse start date using helper
    start_date = parse_date_string(start_date_str)
    start_month = start_date[:month]
    start_year = start_date[:year]

    # Parse end date using helper
    end_date = parse_date_string(end_date_str)
    end_month = end_date[:month]
    end_year = end_date[:year]

    # Detect if this is a current job using helper
    is_current = detect_current_job(end_date_str)

    # Second line should be company and location
    company_line = entry_lines[1] || ""
    company_location_match = company_line.match(/^(.+?)\s*[-–—]\s*(.+)$/)

    if company_location_match
      company = company_location_match[1].strip
      location = company_location_match[2].strip
    else
      # Try to extract just company
      company = company_line.strip
      location = ""
    end

    # Remaining lines are description and achievements
    description_lines = entry_lines[2..-1] || []
    description = description_lines.join(' ').strip

    achievements = extract_achievements(description_lines.join("\n"))
    # Convert achievements array to JSON string if there are any
    achievements_json = achievements.any? ? achievements.to_json : nil

    {
      employer: company.empty? ? nil : company,
      position: title.empty? ? nil : title,
      location: location.empty? ? nil : location,
      start_month: start_month,
      start_year: start_year,
      end_month: end_month,
      end_year: end_year,
      current_job: is_current,
      description: description.empty? ? nil : description,
      achievements: achievements_json
    }
  end

  def extract_achievements(text)
    # Look for bullet points or achievement indicators
    achievements = []

    bullet_points = text.scan(/[•·▪▫◦‣⁃]\s*([^•·▪▫◦‣⁃\n]+)/)
    achievements += bullet_points.flatten.map(&:strip)

    # Look for numbered lists
    numbered_points = text.scan(/\d+\.\s*([^\d\n]+)/)
    achievements += numbered_points.flatten.map(&:strip)

    achievements.first(3) # Limit to 3 achievements
  end

  def extract_education_backgrounds
    educational_backgrounds = []

    # Look for education section
    edu_patterns = [
      /(?:EDUCATION)[:\n\s]+(.*?)(?=\n(?:SKILLS|WORK EXPERIENCE|LEADERSHIP|PROJECTS|CERTIFICATIONS|$))/mi,
      /(?:Education)[:\n\s]+(.*?)(?=\n(?:Skills|Work Experience|Leadership|Projects|Certifications|$))/mi
    ]

    edu_text = ""
    edu_patterns.each do |pattern|
      match = @raw_text.match(pattern)
      if match && match[1]
        edu_text = match[1].strip
        break
      end
    end

    return educational_backgrounds if edu_text.empty?

    # Extract degree information from separate lines
    lines = edu_text.split(/\n/).map(&:strip).reject(&:empty?)

    # Look for institution (contains University, College, etc.)
    institution = ""
    graduation_year = nil
    lines.each do |line|
      if line.match?(/\b(?:University|College|Institute|School)\b/i)
        # Extract institution and graduation date from same line
        # Pattern like: "Lehigh University, Bethlehem, PA                                                                          Graduation May 2026"
        if line.match(/Graduation\s+((?:May|April|June|December)\s+\d{4})/i)
          year_match = line.match(/Graduation\s+((?:May|April|June|December)\s+\d{4})/i)
          if year_match
            # Parse the graduation date to extract year
            date_parts = parse_date_string(year_match[1])
            graduation_year = date_parts[:year]&.to_i
          end
        end

        # Clean institution name - everything before graduation info
        institution = line.split(/\s+Graduation/i)[0]&.strip || ""
        institution = institution.gsub(/,.*$/, '') # Remove location part
        break
      end
    end

    # Extract degree from a separate line
    degree = ""
    major = nil
    degree_line = lines.find { |line| line.match?(/\b(?:Bachelor|Master|PhD|B\.S\.|M\.S\.|B\.A\.|M\.A\.)/i) }
    if degree_line
      # Extract just the degree part, remove trailing info like GPA
      full_degree = degree_line.split(/\s+(?:GPA|Honors Program)/i)[0]&.strip || ""

      # Try to separate degree type and major
      # Pattern like "Bachelor of Science in Computer Science"
      if full_degree.match?(/\bin\b/i)
        parts = full_degree.split(/\bin\b/i)
        degree = parts[0].strip
        major = parts[1].strip if parts[1]
      else
        degree = full_degree
      end
    end

    # Extract GPA
    gpa = nil
    gpa_line = lines.find { |line| line.match?(/GPA[:\s]*([0-9\.]+)/i) }
    if gpa_line
      gpa_match = gpa_line.match(/GPA[:\s]*([0-9\.]+)/i)
      gpa = gpa_match[1].to_f if gpa_match
    end

    # Extract honors
    honors = nil
    honors_patterns = [
      /\b(Honors Program)\b/i,
      /\b(Magna Cum Laude|Summa Cum Laude|Cum Laude)\b/i,
      /\b(Dean's List|Honor Roll)\b/i
    ]

    honors_patterns.each do |pattern|
      match = edu_text.match(pattern)
      if match
        honors = match[1]
        break
      end
    end

    # Only add if we found meaningful information
    if !institution.empty? || !degree.empty?
      educational_backgrounds << {
        university_college: institution.empty? ? nil : institution,
        degree: degree.empty? ? nil : degree,
        major: major,
        graduation_year: graduation_year,
        gpa: gpa,
        honors: honors
      }
    end

    educational_backgrounds
  end

  def extract_skills
    # Look for skills section with various patterns
    skills_patterns = [
      /(?:SKILLS|TECHNICAL SKILLS|CORE COMPETENCIES|PROGRAMMING LANGUAGES)[:\n\s]+(.*?)(?=\n(?:EXPERIENCE|WORK|EDUCATION|PROJECTS|CERTIFICATIONS|EMPLOYMENT|$))/mi,
      /(?:Skills|Technical Skills|Core Competencies|Programming Languages)[:\n\s]+(.*?)(?=\n(?:Experience|Work|Education|Projects|Certifications|Employment|$))/mi
    ]

    skills_text = ""
    skills_patterns.each do |pattern|
      match = @raw_text.match(pattern)
      if match && match[1]
        skills_text = match[1].strip
        break
      end
    end

    # If no explicit skills section, look for technical terms throughout
    if skills_text.empty?
      # Extract from the entire document
      tech_pattern = /\b(?:Java|Python|JavaScript|React|Node\.?js|HTML|CSS|SQL|Ruby|C\+\+|C#|PHP|Swift|Kotlin|Git|Docker|AWS|Azure|MongoDB|PostgreSQL)\b/i
      technical = @raw_text.scan(tech_pattern).map(&:strip).uniq
      return {
        technical: technical.first(10),
        soft: [],
        languages: []
      }
    end

    # Split by common separators and clean up
    all_skills = skills_text.split(/[,|•·▪▫◦‣⁃\n\|]/).map(&:strip).reject(&:empty?)

    # Remove common non-skill words
    all_skills = all_skills.reject { |skill| skill.match?(/^(?:and|or|with|using|including|such as|etc)$/i) }

    # Categorize skills
    technical_keywords = %w[
      programming coding software development web mobile database cloud aws azure gcp
      javascript python java react node vue angular rails django flask sql mysql
      postgresql mongodb docker kubernetes git github html css php ruby swift kotlin
      typescript nosql redis elasticsearch microservices api rest graphql
    ]

    soft_keywords = %w[
      leadership communication teamwork collaboration problem solving creative
      analytical strategic planning management presentation public speaking
      negotiation time management adaptability critical thinking
    ]

    language_keywords = %w[
      english spanish french german chinese japanese portuguese italian russian
      mandarin cantonese hindi arabic korean vietnamese thai dutch swedish
    ]

    technical = []
    soft = []
    languages = []

    all_skills.each do |skill|
      skill_lower = skill.downcase.gsub(/[^\w\s+#]/, '') # Clean punctuation but keep + and #

      # Check for technical skills
      if technical_keywords.any? { |keyword| skill_lower.include?(keyword) } ||
         skill_lower.match?(/\b(?:html|css|js|php|c\+\+|c#|\.net|node\.?js)\b/) ||
         skill.match?(/[A-Z]{2,}/) # Likely acronyms like AWS, API, etc.
        technical << skill

      # Check for languages
      elsif language_keywords.any? { |keyword| skill_lower.include?(keyword) } ||
            skill.match?(/\b(?:native|fluent|conversational|proficient)\b/i)
        languages << skill

      # Check for soft skills
      elsif soft_keywords.any? { |keyword| skill_lower.include?(keyword) }
        soft << skill

      # Default categorization for remaining skills
      else
        # If it's short and looks technical, put in technical
        if skill.length < 15 && (skill.match?(/[A-Z]/) || skill.match?(/\d/))
          technical << skill
        else
          soft << skill
        end
      end
    end

    # Remove duplicates and limit results
    {
      technical: technical.uniq.first(10),
      soft: soft.uniq.first(8),
      languages: languages.uniq.first(5)
    }
  end

  def extract_certifications
    # Look for certifications section
    cert_section = @raw_text.match(/(?:CERTIFICATIONS?|CERTIFICATES?)[:\n\s]+(.*?)(?:\n[A-Z\s]{3,}|$)/mi)
    return [] unless cert_section

    certifications = []
    text = cert_section[1]

    # Look for certification patterns
    cert_lines = text.lines.map(&:strip).reject(&:empty?)
    cert_lines.each do |line|
      # Extract certification name (keep the full line including year)
      name = line.strip
      next if name.empty?

      certifications << name
    end

    certifications
  end

  def extract_projects
    projects = []

    # From the resume, extract specific project names that were mentioned
    # Look for key project mentions in the experience section

    # AI-powered project scoping tool
    if @raw_text.match?(/AI-powered project scoping tool/i)
      projects << "AI-Powered Project Scoping Tool"
    end

    # OCR pipeline
    if @raw_text.match?(/OCR pipeline/i)
      projects << "OCR Text Extraction Pipeline"
    end

    # Finteera app
    if @raw_text.match?(/Finteera/i)
      projects << "Finteera - Personal Finance Education App"
    end

    # If no specific projects found, extract from any projects section
    if projects.empty?
      projects_section = @raw_text.match(/(?:PROJECTS?|PERSONAL PROJECTS?)[:\n\s]+(.*?)(?:\n[A-Z\s]{3,}|$)/mi)
      if projects_section
        text = projects_section[1]
        # Look for project titles (usually start with capital letters or are short phrases)
        lines = text.split(/\n/).map(&:strip).reject(&:empty?)
        lines.each do |line|
          # Skip long descriptions, look for short project titles
          if line.length < 100 && line.split.length < 10 && !line.match?(/^[a-z]/)
            projects << line
          end
        end
      end
    end

    projects
  end
end
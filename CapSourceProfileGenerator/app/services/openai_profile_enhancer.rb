# frozen_string_literal: true

require 'openai'

# OpenAI-powered profile enhancement service following CapSource patterns
# Enhances resume data extracted by ResumeParser using AI to improve quality,
# accuracy, and professional presentation
#
# Usage:
#   enhancer = OpenaiProfileEnhancer.new
#   enhanced_data = enhancer.enhance_profile_data(profile_data)
#
# Input structure (from ResumeParser):
#   {
#     user: { first_name, last_name, email, phone_number, location, linkedin, website, type },
#     profile: { about, status },
#     educational_backgrounds: [{ university_college, degree, major, graduation_year, gpa, honors }],
#     professional_backgrounds: [{ employer, position, location, start_month, start_year, end_month, end_year, current_job, description, achievements }],
#     skills: { technical: [], soft: [], languages: [] },
#     certifications: [{ name, issuer, date }],
#     projects: [{ name, description, technologies: [] }]
#   }
#
# Output: Enhanced version of the same structure with improved content
class OpenaiProfileEnhancer
  include AiParsingHelpers

  MAX_RETRIES = 3
  RETRY_WAIT_SECONDS = 15

  def initialize
    @client = OpenAI::Client.new(
      access_token: ENV['OPENAI_API_KEY'],
      organization_id: ENV['OPENAI_ORGANIZATION_ID'] # Optional
    )
  end

  # NEW METHOD: Extract comprehensive profile data from raw resume text
  def extract_from_raw_text(raw_text)
    Rails.logger.info 'Extracting comprehensive profile data from raw resume text with OpenAI...'

    retries = 0

    begin
      prompt = build_raw_extraction_prompt(raw_text)

      response = @client.chat(
        parameters: {
          model: ENV['OPENAI_MODEL'] || 'gpt-4o',  # Use more powerful model for extraction
          messages: [
            {
              role: 'system',
              content: extraction_system_prompt
            },
            {
              role: 'user',
              content: prompt
            }
          ],
          max_tokens: 8000,  # Increased even more for comprehensive extraction
          temperature: 0.05 # Extremely low temperature for accurate extraction
        }
      )

      content = response.dig('choices', 0, 'message', 'content')&.strip

      if content.blank?
        Rails.logger.error 'Empty response content from OpenAI extraction'
        return build_empty_profile_structure
      end

      # Log the raw AI response for debugging
      Rails.logger.info "=== RAW OPENAI RESPONSE START ==="
      Rails.logger.info content
      Rails.logger.info "=== RAW OPENAI RESPONSE END ==="

      Rails.logger.info 'Successfully extracted profile data from raw text with OpenAI'

      # Parse the JSON response
      begin
        ai_data = JSON.parse(content)
        parsed_result = convert_json_to_capsource_format(ai_data)

        # Log parsed result counts for debugging
        Rails.logger.info "Parsed #{parsed_result[:educational_backgrounds]&.length || 0} education entries"
        Rails.logger.info "Parsed #{parsed_result[:professional_backgrounds]&.length || 0} professional entries"
        Rails.logger.info "Parsed #{parsed_result[:skills][:technical]&.length || 0} technical skills"

        parsed_result
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse JSON from OpenAI: #{e.message}"
        Rails.logger.error "Content was: #{content[0..500]}"
        return build_empty_profile_structure
      end

    rescue OpenAI::Error => e
      Rails.logger.error "OpenAI API error during extraction: #{e.class} - #{e.message}"

      if retryable_error?(e) && retries < MAX_RETRIES
        retries += 1
        Rails.logger.info "Retrying extraction (attempt #{retries}/#{MAX_RETRIES})..."
        sleep(RETRY_WAIT_SECONDS)
        retry
      end

      Rails.logger.error 'Non-retryable or max retries exceeded for OpenAI extraction error'
      build_empty_profile_structure

    rescue StandardError => e
      Rails.logger.error "Unexpected error in extract_from_raw_text: #{e.class} - #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      build_empty_profile_structure
    end
  end

  # Main enhancement method following CapSource pattern
  # Accepts and returns CapSource-compatible profile structure
  def enhance_profile_data(profile_data)
    Rails.logger.info 'Enhancing profile data with OpenAI...'

    retries = 0

    begin
      prompt = build_enhancement_prompt(profile_data)

      response = @client.chat(
        parameters: {
          model: ENV['OPENAI_MODEL'] || 'gpt-4o-mini',
          messages: [
            {
              role: 'system',
              content: system_prompt
            },
            {
              role: 'user',
              content: prompt
            }
          ],
          max_tokens: 3500,
          temperature: 0.3 # Lower temperature for more consistent results
        }
      )

      content = response.dig('choices', 0, 'message', 'content')&.strip

      if content.blank?
        Rails.logger.error 'Empty response content from OpenAI'
        return profile_data
      end

      Rails.logger.info 'Successfully received enhanced profile from OpenAI'
      merge_enhanced_data(profile_data, parse_enhanced_profile(content))

    rescue OpenAI::Error => e
      Rails.logger.error "OpenAI API error: #{e.class} - #{e.message}"

      # Distinguish retryable vs non-retryable errors
      if retryable_error?(e) && retries < MAX_RETRIES
        retries += 1
        Rails.logger.info "Retrying profile enhancement (attempt #{retries}/#{MAX_RETRIES})..."
        sleep(RETRY_WAIT_SECONDS)
        retry
      end

      Rails.logger.error 'Non-retryable or max retries exceeded for OpenAI error'
      profile_data

    rescue StandardError => e
      Rails.logger.error "Unexpected error in enhance_profile_data: #{e.class} - #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      profile_data
    end
  end

  private

  # Check if error is retryable (500s, 502, 503, rate limits)
  def retryable_error?(error)
    error.message.include?('500') ||
      error.message.include?('502') ||
      error.message.include?('503') ||
      error.message.include?('rate_limit') ||
      error.message.include?('timeout')
  end

  def system_prompt
    <<~PROMPT
      You are an expert resume analyzer and professional profile enhancer. Your task is to:

      1. Analyze extracted profile data and improve its quality
      2. Generate compelling professional summaries when missing or weak
      3. Enhance work experience descriptions to be more impactful and results-oriented
      4. Improve skills categorization and identify missing relevant skills
      5. Enhance education information with relevant details
      6. Create clear, professional project descriptions
      7. Extract and highlight quantifiable achievements

      Always respond using FIELD MARKERS in the exact format requested. Do not use JSON.

      Focus on:
      - Professional language and impact-oriented descriptions
      - Quantifiable achievements with metrics where possible
      - Industry-standard skill categorization
      - Clear, concise descriptions
      - Professional summaries that highlight key strengths and career focus
      - Accurate preservation of factual information (names, dates, companies, etc.)
    PROMPT
  end

  def build_enhancement_prompt(profile_data)
    user = profile_data[:user] || {}
    profile = profile_data[:profile] || {}
    education = profile_data[:educational_backgrounds] || []
    experience = profile_data[:professional_backgrounds] || []
    skills = profile_data[:skills] || {}
    certifications = profile_data[:certifications] || []
    projects = profile_data[:projects] || []

    # Build current data summary
    current_data = build_current_data_summary(user, profile, education, experience, skills, certifications, projects)

    <<~PROMPT
      Please analyze this extracted profile data and enhance it to be more professional and impactful:

      CURRENT PROFILE DATA:
      #{current_data}

      Please return enhanced data using EXACTLY these field markers and format:

      PROFESSIONAL_SUMMARY: [A compelling 2-3 sentence professional summary highlighting key skills, experience level, career focus, and unique value proposition. Make it engaging and tailored to the person's background.]

      EDUCATION: [For each education entry, provide enhanced information in this format, separated by "---" between entries:
      University: [Full institution name]
      Degree: [Full degree name with major/concentration]
      Graduation: [Month Year or Year]
      GPA: [GPA if available, otherwise omit this line]
      Honors: [Academic honors, awards, or distinctions if any, otherwise omit this line]
      ---]

      EXPERIENCE: [For each work experience, provide enhanced information in this format, separated by "---" between entries:
      Position: [Job title]
      Company: [Company name]
      Location: [City, State or City, Country]
      Start Date: [Month/Year format, e.g., "January/2023"]
      End Date: [Month/Year format, e.g., "December/2023" or "Current" for current jobs]
      Description: [Enhanced 1-2 sentence overview emphasizing role impact and key responsibilities]
      Achievements:
      • [Quantified achievement with specific metrics and impact]
      • [Another achievement showing results and business value]
      • [Third achievement demonstrating skills and outcomes]
      ---]

      TECHNICAL_SKILLS: [Comma-separated list of technical skills, tools, programming languages, frameworks, and technologies. Include 8-12 relevant items.]

      SOFT_SKILLS: [Comma-separated list of soft skills and competencies like leadership, communication, problem-solving, etc. Include 5-8 relevant items.]

      LANGUAGES: [Comma-separated list of languages with proficiency levels in format "Language (Proficiency)", e.g., "English (Native), Spanish (Conversational)". Include all mentioned languages.]

      CERTIFICATIONS: [For each certification, provide in this format, separated by "---" between entries:
      Name: [Full certification name]
      Issuer: [Issuing organization]
      Date: [Year or Month Year]
      ---]

      PROJECTS: [For each project, provide in this format, separated by "---" between entries:
      Name: [Clear, descriptive project name]
      Description: [Brief 1-2 sentence description of the project, its purpose, and impact]
      Technologies: [Comma-separated list of technologies, tools, and frameworks used]
      ---]

      CRITICAL INSTRUCTIONS:
      1. Enhance the professional summary to be compelling and highlight unique strengths
      2. Improve work experience descriptions to be impactful and results-oriented
      3. Extract and emphasize quantifiable achievements with specific metrics
      4. Use action verbs and professional language throughout
      5. Categorize skills accurately - separate technical from soft skills
      6. Ensure all factual information (names, dates, companies, schools) remains accurate
      7. For achievements, look for numbers, percentages, dollar amounts, time savings, or other metrics
      8. Format dates consistently as "Month/Year" for experience (e.g., "January/2023")
      9. Use "Current" for end date of current positions
      10. If information is missing, use context to infer reasonable content but keep it professional
      11. Ensure project descriptions are clear and show the value/purpose of each project
      12. For education graduation dates, use "Month Year" format (e.g., "May 2026")

      IMPORTANT: Use the exact field names shown above with colons (e.g., "PROFESSIONAL_SUMMARY:", "EDUCATION:", etc.). Separate multiple entries within sections using "---" as shown.
    PROMPT
  end

  def build_current_data_summary(user, profile, education, experience, skills, certifications, projects)
    summary = []

    # User/Personal Info
    summary << "Name: #{user[:first_name]} #{user[:last_name]}".strip
    summary << "Email: #{user[:email]}" if user[:email].present?
    summary << "Phone: #{user[:phone_number]}" if user[:phone_number].present?
    summary << "Location: #{user[:location]}" if user[:location].present?
    summary << "LinkedIn: #{user[:linkedin]}" if user[:linkedin].present?
    summary << "Website: #{user[:website]}" if user[:website].present?

    # Professional Summary
    summary << "\nCurrent Professional Summary: #{profile[:about]}" if profile[:about].present?

    # Education
    if education.any?
      summary << "\nEducation:"
      education.each do |edu|
        summary << "  - #{edu[:degree]} in #{edu[:major]} from #{edu[:university_college]}, #{edu[:graduation_year]}"
        summary << "    GPA: #{edu[:gpa]}" if edu[:gpa].present?
        summary << "    Honors: #{edu[:honors]}" if edu[:honors].present?
      end
    end

    # Experience
    if experience.any?
      summary << "\nWork Experience:"
      experience.each do |exp|
        date_range = "#{exp[:start_month]}/#{exp[:start_year]} - #{exp[:current_job] ? 'Current' : "#{exp[:end_month]}/#{exp[:end_year]}"}"
        summary << "  - #{exp[:position]} at #{exp[:company]} (#{date_range})"
        summary << "    Location: #{exp[:location]}" if exp[:location].present?
        summary << "    Description: #{exp[:description]}" if exp[:description].present?
        if exp[:achievements].present?
          achievements_text = exp[:achievements].is_a?(Array) ? exp[:achievements].join('; ') : exp[:achievements]
          summary << "    Achievements: #{achievements_text}"
        end
      end
    end

    # Skills
    if skills.any?
      summary << "\nSkills:"
      summary << "  Technical: #{skills[:technical]&.join(', ')}" if skills[:technical]&.any?
      summary << "  Soft Skills: #{skills[:soft]&.join(', ')}" if skills[:soft]&.any?
      summary << "  Languages: #{skills[:languages]&.join(', ')}" if skills[:languages]&.any?
    end

    # Certifications
    if certifications.any?
      summary << "\nCertifications:"
      certifications.each do |cert|
        # Handle both string certifications and hash certifications
        if cert.is_a?(Hash)
          summary << "  - #{cert[:name]} from #{cert[:issuer]} (#{cert[:date]})"
        else
          # Certification is just a string
          summary << "  - #{cert}"
        end
      end
    end

    # Projects
    if projects.any?
      summary << "\nProjects:"
      projects.each do |proj|
        # Handle both string projects and hash projects
        if proj.is_a?(Hash)
          summary << "  - #{proj[:name]}"
          summary << "    Description: #{proj[:description]}" if proj[:description].present?
          summary << "    Technologies: #{proj[:technologies]&.join(', ')}" if proj[:technologies]&.any?
        else
          # Project is just a string name
          summary << "  - #{proj}"
        end
      end
    end

    summary.join("\n")
  end

  # Parse AI response using field markers (following ProjectScopeGenerator pattern)
  def parse_enhanced_profile(content)
    {
      professional_summary: extract_field(content, 'PROFESSIONAL_SUMMARY'),
      education: parse_education_entries(content),
      experience: parse_experience_entries(content),
      technical_skills: parse_skills_list(content, 'TECHNICAL_SKILLS'),
      soft_skills: parse_skills_list(content, 'SOFT_SKILLS'),
      languages: parse_skills_list(content, 'LANGUAGES'),
      certifications: parse_certification_entries(content),
      projects: parse_project_entries(content)
    }
  end

  # Parse education entries separated by "---"
  def parse_education_entries(content)
    education_text = extract_field(content, 'EDUCATION')
    return [] if education_text.blank?

    entries = education_text.split('---').map(&:strip).reject(&:blank?)

    entries.map do |entry|
      university = extract_from_entry(entry, 'University')
      degree = extract_from_entry(entry, 'Degree')
      graduation = extract_from_entry(entry, 'Graduation')
      gpa = extract_from_entry(entry, 'GPA')
      honors = extract_from_entry(entry, 'Honors')

      # Parse graduation date
      grad_date = parse_date_string(graduation || '')

      {
        university_college: university,
        degree: degree,
        major: extract_major_from_degree(degree),
        graduation_year: grad_date[:year],
        month_start: nil,
        month_end: grad_date[:month],
        year_start: nil,
        year_end: grad_date[:year],
        gpa: parse_gpa(gpa),
        honors: honors
      }.compact
    end
  end

  # Parse experience entries separated by "---"
  def parse_experience_entries(content)
    experience_text = extract_field(content, 'EXPERIENCE')
    return [] if experience_text.blank?

    entries = experience_text.split('---').map(&:strip).reject(&:blank?)

    entries.map do |entry|
      position = extract_from_entry(entry, 'Position')
      company = extract_from_entry(entry, 'Company')
      location = extract_from_entry(entry, 'Location')
      start_date = extract_from_entry(entry, 'Start Date')
      end_date = extract_from_entry(entry, 'End Date')
      description = extract_from_entry(entry, 'Description')
      achievements = extract_achievements_from_entry(entry)

      # Parse dates (format: "Month/Year")
      start_parsed = parse_experience_date(start_date)
      end_parsed = parse_experience_date(end_date)
      is_current = detect_current_job(end_date)

      {
        employer: company,
        position: position,
        location: location,
        start_month: start_parsed[:month],
        start_year: start_parsed[:year],
        end_month: is_current ? nil : end_parsed[:month],
        end_year: is_current ? nil : end_parsed[:year],
        current_job: is_current,
        description: description,
        achievements: format_text_as_bullet_points(achievements)
      }.compact
    end
  end

  # Parse certification entries separated by "---"
  def parse_certification_entries(content)
    cert_text = extract_field(content, 'CERTIFICATIONS')
    return [] if cert_text.blank?

    entries = cert_text.split('---').map(&:strip).reject(&:blank?)

    entries.map do |entry|
      name = extract_from_entry(entry, 'Name')
      issuer = extract_from_entry(entry, 'Issuer')
      date = extract_from_entry(entry, 'Date')

      {
        name: name,
        issuer: issuer,
        date: date
      }.compact
    end
  end

  # Parse project entries separated by "---"
  def parse_project_entries(content)
    project_text = extract_field(content, 'PROJECTS')
    return [] if project_text.blank?

    entries = project_text.split('---').map(&:strip).reject(&:blank?)

    entries.map do |entry|
      name = extract_from_entry(entry, 'Name')
      description = extract_from_entry(entry, 'Description')
      technologies = extract_from_entry(entry, 'Technologies')

      {
        name: name,
        description: description,
        technologies: technologies ? technologies.split(',').map(&:strip) : []
      }.compact
    end
  end

  # Parse comma-separated skills list
  def parse_skills_list(content, field_name)
    skills_text = extract_field(content, field_name)
    return [] if skills_text.blank?

    skills_text.split(',').map(&:strip).reject(&:blank?)
  end

  # Extract a field value from an entry block
  def extract_from_entry(entry, field_name)
    pattern = /#{Regexp.escape(field_name)}:\s*(.+?)(?=\n[A-Z][a-z]+:|$)/mi
    match = entry.match(pattern)
    match ? match[1].strip : nil
  end

  # Extract achievements list from entry (bullet points)
  def extract_achievements_from_entry(entry)
    achievements_match = entry.match(/Achievements:\s*(.+?)(?=\n[A-Z][a-z]+:|---|\z)/mi)
    return '' if achievements_match.nil?

    achievements_match[1].strip
  end

  # Parse experience date in "Month/Year" format
  def parse_experience_date(date_str)
    return { month: nil, year: nil } if date_str.blank? || date_str =~ /current|present/i

    # Handle "Month/Year" format
    if date_str.include?('/')
      parts = date_str.split('/')
      month = parts[0]&.strip
      year = parts[1]&.strip
      { month: month, year: year }
    else
      # Fallback to parse_date_string helper
      parse_date_string(date_str)
    end
  end

  # Parse GPA string to decimal
  def parse_gpa(gpa_str)
    return nil if gpa_str.blank?

    # Extract numeric value
    gpa_match = gpa_str.match(/(\d+\.?\d*)/)
    gpa_match ? gpa_match[1].to_f : nil
  end

  # Parse graduation date string (e.g., "May 2026" or "2026")
  def parse_graduation_date(date_str)
    return [nil, nil] if date_str.blank?

    # Try to extract month and year
    if date_str.match(/(\w+)\s+(\d{4})/)
      month = $1
      year = $2.to_i
      [month, year]
    elsif date_str.match(/(\d{4})/)
      [nil, $1.to_i]
    else
      [nil, nil]
    end
  end

  # Extract major from degree string
  def extract_major_from_degree(degree_str)
    return nil if degree_str.blank?

    # Look for "in [Major]" pattern
    major_match = degree_str.match(/\bin\s+(.+?)(?:\s+from|\s+at|$)/i)
    if major_match
      major_match[1].strip
    else
      # If no "in" keyword, assume everything after degree type is the major
      degree_str.gsub(/^(Bachelor|Master|PhD|B\.S\.|M\.S\.|B\.A\.|M\.A\.|Associate).+?(of|in)\s+/i, '').strip
    end
  end

  # Merge enhanced data back into original structure
  def merge_enhanced_data(original_data, enhanced_data)
    merged = original_data.deep_dup

    # Update professional summary
    if enhanced_data[:professional_summary].present?
      merged[:profile] ||= {}
      merged[:profile][:about] = enhanced_data[:professional_summary]
    end

    # Update education
    if enhanced_data[:education]&.any?
      merged[:educational_backgrounds] = enhanced_data[:education]
    end

    # Update experience
    if enhanced_data[:experience]&.any?
      merged[:professional_backgrounds] = enhanced_data[:experience]
    end

    # Update skills
    merged[:skills] ||= {}
    merged[:skills][:technical] = enhanced_data[:technical_skills] if enhanced_data[:technical_skills]&.any?
    merged[:skills][:soft] = enhanced_data[:soft_skills] if enhanced_data[:soft_skills]&.any?
    merged[:skills][:languages] = enhanced_data[:languages] if enhanced_data[:languages]&.any?

    # Update certifications
    if enhanced_data[:certifications]&.any?
      merged[:certifications] = enhanced_data[:certifications]
    end

    # Update projects
    if enhanced_data[:projects]&.any?
      merged[:projects] = enhanced_data[:projects]
    end

    merged
  end

  # System prompt for raw text extraction
  def extraction_system_prompt
    <<~PROMPT
      You are an expert resume analyzer with exceptional attention to detail. Your task is to extract comprehensive, accurate information from a resume.

      CRITICAL REQUIREMENTS:
      1. Extract information EXACTLY as it appears - do not change names, universities, companies, or dates
      2. Extract ALL work experiences from BOTH "WORK EXPERIENCE" and "LEADERSHIP EXPERIENCE" sections
      3. Count the total number of positions FIRST before extracting to ensure you get them all
      4. Preserve all quantifiable metrics, achievements, and specific details
      5. If information is clearly stated, extract it verbatim
      6. Pay special attention to the person's full name at the top of the resume
      7. Extract the correct university/college name without changing it

      CRITICAL: If a resume has 5 work experiences (e.g., 4 under "WORK EXPERIENCE" + 1 under "LEADERSHIP EXPERIENCE"),
      you MUST return a JSON with all 5 entries in the "experience" array. Do not stop after just 1-2 entries.

      Always respond with valid JSON in the exact format requested. Do not include any text outside the JSON structure.
    PROMPT
  end

  # Build comprehensive extraction prompt from raw resume text using JSON format
  def build_raw_extraction_prompt(raw_text)
    <<~PROMPT
      Please analyze this resume text and extract all information comprehensively and accurately.

      CRITICAL INSTRUCTIONS:
      1. Count ALL work positions FIRST (look in BOTH "WORK EXPERIENCE" and "LEADERSHIP EXPERIENCE" sections)
      2. Extract EVERY single position - if there are 5 total, your JSON must have 5 entries in the "experience" array
      3. Extract information EXACTLY as written - do not change names, universities, or companies
      4. Extract ALL skills from BOTH "Programming Languages" and "Tools" subsections
      5. Extract ALL certifications/awards mentioned

      RAW RESUME TEXT:
      #{raw_text}

      Please return data in this EXACT JSON format (and ONLY valid JSON, no other text):
      {
        "personalInfo": {
          "fullName": "Extract exact full name from top of resume",
          "email": "email address",
          "phone": "phone number",
          "location": "City, State",
          "linkedin": "linkedin url or empty string",
          "website": "website url or empty string"
        },
        "professionalSummary": "Create a compelling 2-3 sentence professional summary highlighting key skills, experience, and career focus based on the resume content",
        "experience": [
          {
            "title": "Job Title",
            "company": "Full Company Name (e.g., 'Comcast Corporation - Internet Essentials Program', 'Society of Asian Scientists and Engineers (SASE)')",
            "location": "City, State",
            "startDate": "Month Year (e.g., 'June 2025')",
            "endDate": "Month Year or 'Present' for current jobs",
            "description": "Brief 1-2 sentence overview of the role",
            "keyAchievements": [
              "Each bullet point achievement from the resume with all metrics preserved",
              "Include ALL bullet points listed under this position",
              "Keep numbers, percentages, amounts (e.g., 2.5M+, 20K+, 80%, $2,500)"
            ]
          }
        ],
        "education": [
          {
            "degree": "Full degree name (e.g., 'Bachelor of Science in Computer Science and Business Honors Program')",
            "institution": "EXACT university name as written (e.g., 'Lehigh University')",
            "graduationYear": "Month Year (e.g., 'May 2026')",
            "gpa": "Exact GPA (e.g., '3.54') or null",
            "honors": "Honors/distinctions (e.g., 'Honors Program') or null"
          }
        ],
        "skills": {
          "technical": ["All programming languages", "All tools", "All frameworks", "All technologies"],
          "soft": ["Leadership", "Communication", "Problem-Solving", "Teamwork", "etc."],
          "languages": ["Language skills if any, otherwise empty array"]
        },
        "certifications": [
          {
            "name": "Certification/Award name",
            "issuer": "Issuing organization if mentioned",
            "date": "Year if mentioned"
          }
        ],
        "projects": [
          {
            "name": "Project name",
            "description": "Brief project description",
            "technologies": ["Tech 1", "Tech 2"]
          }
        ]
      }

      REMINDER FOR EXPERIENCE ARRAY:
      - Scan the entire resume for work experience sections (e.g., "WORK EXPERIENCE", "EXPERIENCE", "EMPLOYMENT", "PROFESSIONAL EXPERIENCE")
      - Also scan for leadership/volunteer sections (e.g., "LEADERSHIP EXPERIENCE", "VOLUNTEER EXPERIENCE", "ACTIVITIES")
      - Count ALL positions across ALL relevant sections
      - Your JSON "experience" array length MUST equal the total number of positions found
      - DO NOT stop after extracting just 1-2 entries - extract them ALL

      REMINDER FOR SKILLS:
      - Look for SKILLS section (may be labeled "SKILLS", "TECHNICAL SKILLS", "CORE COMPETENCIES", etc.)
      - Extract ALL technical skills including: programming languages, tools, frameworks, databases, cloud platforms, etc.
      - If skills are divided into subsections (e.g., "Programming Languages:", "Tools:", "Frameworks:"), combine them all into the "technical" array
      - Extract soft skills like Leadership, Communication, Problem-Solving, Teamwork, Project Management, etc.

      REMINDER FOR CERTIFICATIONS:
      - Look for certifications section (may be labeled "CERTIFICATIONS", "CERTIFICATIONS/AWARDS", "AWARDS", etc.)
      - Extract each certification/award as a separate object
      - Include the exact name as written and any issuer/date information if provided

      Return ONLY the JSON, no other text before or after.
    PROMPT
  end

  # Convert JSON response from OpenAI to CapSource format
  def convert_json_to_capsource_format(ai_data)
    personal_info = ai_data['personalInfo'] || {}

    # Split full name into first and last
    full_name = personal_info['fullName'] || ''
    name_parts = split_full_name(full_name)

    {
      user: {
        first_name: name_parts[:first_name],
        last_name: name_parts[:last_name],
        email: personal_info['email'] || '',
        phone_number: personal_info['phone'] || '',
        location: personal_info['location'] || '',
        linkedin: personal_info['linkedin'] || '',
        website: personal_info['website'] || '',
        type: 'Users::Student'
      },
      profile: {
        about: ai_data['professionalSummary'] || '',
        status: 'draft'
      },
      educational_backgrounds: convert_education_from_json(ai_data['education'] || []),
      professional_backgrounds: convert_experience_from_json(ai_data['experience'] || []),
      skills: {
        technical: ai_data.dig('skills', 'technical') || [],
        soft: ai_data.dig('skills', 'soft') || [],
        languages: ai_data.dig('skills', 'languages') || []
      },
      certifications: ai_data['certifications'] || [],
      projects: ai_data['projects'] || []
    }
  end

  # Convert education entries from JSON to CapSource format
  def convert_education_from_json(education_array)
    education_array.map do |edu|
      # Extract graduation info
      graduation_str = edu['graduationYear'] || ''
      graduation_month, graduation_year = parse_graduation_date(graduation_str)

      {
        university_college: edu['institution'] || '',
        degree: edu['degree'] || '',
        major: extract_major_from_degree(edu['degree'] || ''),
        graduation_year: graduation_year,
        gpa: edu['gpa'],
        honors: edu['honors']
      }.compact
    end
  end

  # Convert experience entries from JSON to CapSource format
  def convert_experience_from_json(experience_array)
    experience_array.map do |exp|
      # Parse start date
      start_date_str = exp['startDate'] || ''
      start_parsed = parse_experience_date(start_date_str)

      # Parse end date
      end_date_str = exp['endDate'] || ''
      is_current = detect_current_job(end_date_str)
      end_parsed = parse_experience_date(end_date_str)

      {
        employer: exp['company'] || '',
        position: exp['title'] || '',
        location: exp['location'] || '',
        start_month: start_parsed[:month],
        start_year: start_parsed[:year],
        end_month: is_current ? nil : end_parsed[:month],
        end_year: is_current ? nil : end_parsed[:year],
        current_job: is_current,
        description: exp['description'] || '',
        achievements: format_text_as_bullet_points((exp['keyAchievements'] || []).join("\n"), separator: "\n")
      }.compact
    end
  end

  # Build empty profile structure as fallback
  def build_empty_profile_structure
    {
      user: {
        first_name: 'Name',
        last_name: 'not found',
        email: '',
        phone_number: '',
        location: '',
        linkedin: '',
        website: '',
        type: 'Users::Student'
      },
      profile: {
        about: 'Professional with technical background.',
        status: 'draft'
      },
      educational_backgrounds: [],
      professional_backgrounds: [],
      skills: {
        technical: [],
        soft: [],
        languages: []
      },
      certifications: [],
      projects: []
    }
  end
end

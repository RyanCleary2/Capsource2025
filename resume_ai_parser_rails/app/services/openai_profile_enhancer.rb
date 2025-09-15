require 'openai'

class OpenaiProfileEnhancer
  def initialize
    @client = OpenAI::Client.new(
      access_token: ENV['OPENAI_API_KEY'],
      organization_id: ENV['OPENAI_ORGANIZATION_ID'] # Optional
    )
  end

  def enhance_profile_data(raw_text, basic_profile_data)
    Rails.logger.info "Enhancing profile data with OpenAI..."

    begin
      # Create a comprehensive prompt for profile enhancement
      prompt = build_enhancement_prompt(raw_text, basic_profile_data)

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
          max_tokens: 2000,
          temperature: 0.3 # Lower temperature for more consistent results
        }
      )

      # Parse the JSON response
      ai_enhanced_data = JSON.parse(response.dig('choices', 0, 'message', 'content'))

      # Merge AI enhancements with basic data
      merge_enhanced_data(basic_profile_data, ai_enhanced_data)

    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse OpenAI response: #{e.message}"
      basic_profile_data
    rescue => e
      Rails.logger.error "OpenAI API error: #{e.message}"
      basic_profile_data
    end
  end

  private

  def system_prompt
    <<~PROMPT
      You are an expert resume analyzer and professional profile enhancer. Your task is to:

      1. Analyze the raw resume text and improve the extracted profile data
      2. Generate professional summaries when missing
      3. Enhance work experience descriptions to be more impactful
      4. Improve skills categorization and add missing relevant skills
      5. Extract and organize project information clearly
      6. Ensure all information is accurate and professionally formatted

      Always respond with valid JSON in the exact format requested. Do not include any text outside the JSON structure.

      Focus on:
      - Professional language and impact-oriented descriptions
      - Quantifiable achievements where possible
      - Industry-standard skill categorization
      - Clear, concise project descriptions
      - Professional summary that highlights key strengths
    PROMPT
  end

  def build_enhancement_prompt(raw_text, basic_data)
    <<~PROMPT
      Please analyze this resume text and enhance the extracted profile data:

      RAW RESUME TEXT:
      #{raw_text}

      CURRENT EXTRACTED DATA:
      #{basic_data.to_json}

      Please return enhanced data in this EXACT JSON format:
      {
        "personalInfo": {
          "fullName": "Enhanced full name",
          "email": "email@example.com",
          "phone": "phone number",
          "location": "City, State",
          "website": "website url or null",
          "linkedin": "linkedin url or null"
        },
        "professionalSummary": "A compelling 2-3 sentence professional summary highlighting key skills, experience, and career focus",
        "experience": [
          {
            "title": "Job Title",
            "company": "Company Name",
            "location": "City, State",
            "startDate": "Month Year",
            "endDate": "Month Year or Present",
            "description": "Enhanced 1-2 sentence overview of role and responsibilities",
            "keyAchievements": [
              "Quantified achievement with impact",
              "Another achievement with metrics",
              "Third achievement showing results"
            ]
          }
        ],
        "education": [
          {
            "degree": "Degree Name",
            "institution": "University Name",
            "graduationYear": "Year",
            "gpa": "GPA if available",
            "honors": "Honors if any"
          }
        ],
        "skills": {
          "technical": ["List of technical skills"],
          "soft": ["List of soft skills"],
          "languages": ["List of languages with proficiency"]
        },
        "certifications": [
          {
            "name": "Certification Name",
            "issuer": "Issuing Organization",
            "date": "Year"
          }
        ],
        "projects": [
          {
            "name": "Project Name",
            "description": "Brief description of the project and its impact",
            "technologies": ["Technology 1", "Technology 2"]
          }
        ]
      }

      Instructions:
      1. Enhance the professional summary to be compelling and highlight key strengths
      2. Improve work experience descriptions to be more impactful and results-oriented
      3. Add quantifiable achievements where possible (extract numbers/metrics from the raw text)
      4. Categorize skills more accurately and add relevant missing skills
      5. Extract clear project names and descriptions
      6. Ensure all data is accurate to the original resume
      7. Use professional language throughout
      8. If information is missing or unclear, use the raw text to infer appropriate content
    PROMPT
  end

  def merge_enhanced_data(basic_data, ai_data)
    # Start with AI-enhanced data as the base
    enhanced_data = ai_data.dup

    # Fall back to basic data for any missing or empty fields
    enhanced_data["personalInfo"] ||= {}
    basic_data["personalInfo"]&.each do |key, value|
      if enhanced_data["personalInfo"][key].blank? && value.present?
        enhanced_data["personalInfo"][key] = value
      end
    end

    # Ensure we don't lose any experience entries
    if enhanced_data["experience"].blank? && basic_data["experience"].present?
      enhanced_data["experience"] = basic_data["experience"]
    end

    # Ensure we don't lose education data
    if enhanced_data["education"].blank? && basic_data["education"].present?
      enhanced_data["education"] = basic_data["education"]
    end

    # Merge skills intelligently
    if enhanced_data["skills"].present? && basic_data["skills"].present?
      %w[technical soft languages].each do |skill_type|
        if enhanced_data["skills"][skill_type].blank?
          enhanced_data["skills"][skill_type] = basic_data["skills"][skill_type] || []
        end
      end
    elsif basic_data["skills"].present?
      enhanced_data["skills"] = basic_data["skills"]
    end

    enhanced_data
  end
end
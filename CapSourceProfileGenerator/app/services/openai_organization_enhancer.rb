require 'openai'

class OpenaiOrganizationEnhancer
  include AiParsingHelpers

  def initialize
    @client = OpenAI::Client.new(
      access_token: ENV['OPENAI_API_KEY'],
      organization_id: ENV['OPENAI_ORGANIZATION_ID'] # Optional
    )
  end

  def enhance_company_profile(scraped_data, url)
    Rails.logger.info "Enhancing company profile with OpenAI..."

    retries = 0
    max_retries = 3

    begin
      prompt = build_company_prompt(scraped_data, url)

      response = @client.chat(
        parameters: {
          model: ENV['OPENAI_MODEL'] || 'gpt-4o-mini',
          messages: [
            {
              role: 'system',
              content: company_system_prompt
            },
            {
              role: 'user',
              content: prompt
            }
          ],
          max_tokens: 3500,
          temperature: 0.2
        }
      )

      content = response.dig('choices', 0, 'message', 'content')&.strip

      if content.blank?
        Rails.logger.error 'Empty response content from OpenAI'
        return basic_company_profile(scraped_data, url)
      end

      merge_company_data(scraped_data, content, url)

    rescue OpenAI::Error => e
      Rails.logger.error "OpenAI API error: #{e.class} - #{e.message}"

      if (e.message.include?('500') || e.message.include?('502') || e.message.include?('503') || e.message.include?('rate_limit')) && retries < max_retries
        retries += 1
        Rails.logger.info "Retrying company profile enhancement (attempt #{retries}/#{max_retries})..."
        sleep(2 ** retries) # Exponential backoff: 2s, 4s, 8s
        retry
      end

      Rails.logger.error 'Non-retryable or max retries exceeded for OpenAI error'
      basic_company_profile(scraped_data, url)
    rescue StandardError => e
      Rails.logger.error "Unexpected error in enhance_company_profile: #{e.class} - #{e.message}"
      basic_company_profile(scraped_data, url)
    end
  end

  def enhance_university_profile(scraped_data, url)
    Rails.logger.info "Enhancing university profile with OpenAI..."

    retries = 0
    max_retries = 3

    begin
      prompt = build_university_prompt(scraped_data, url)

      response = @client.chat(
        parameters: {
          model: ENV['OPENAI_MODEL'] || 'gpt-4o-mini',
          messages: [
            {
              role: 'system',
              content: university_system_prompt
            },
            {
              role: 'user',
              content: prompt
            }
          ],
          max_tokens: 3500,
          temperature: 0.2
        }
      )

      content = response.dig('choices', 0, 'message', 'content')&.strip

      if content.blank?
        Rails.logger.error 'Empty response content from OpenAI'
        return basic_university_profile(scraped_data, url)
      end

      merge_university_data(scraped_data, content, url)

    rescue OpenAI::Error => e
      Rails.logger.error "OpenAI API error: #{e.class} - #{e.message}"

      if (e.message.include?('500') || e.message.include?('502') || e.message.include?('503') || e.message.include?('rate_limit')) && retries < max_retries
        retries += 1
        Rails.logger.info "Retrying university profile enhancement (attempt #{retries}/#{max_retries})..."
        sleep(2 ** retries) # Exponential backoff: 2s, 4s, 8s
        retry
      end

      Rails.logger.error 'Non-retryable or max retries exceeded for OpenAI error'
      basic_university_profile(scraped_data, url)
    rescue StandardError => e
      Rails.logger.error "Unexpected error in enhance_university_profile: #{e.class} - #{e.message}"
      basic_university_profile(scraped_data, url)
    end
  end

  private

  # Validates extracted data to prevent data pollution
  # @param data [String] The extracted data value
  # @param field_type [Symbol] The type of field (:url, :year, :text, :pipe_separated)
  # @return [String, nil] Validated data or nil if invalid
  def validate_extracted_data(data, field_type)
    return nil if data.blank?

    data = data.strip

    case field_type
    when :url
      # Validate URL fields - must be valid URLs or return nil
      # Reject field markers, placeholder text, "Not found", etc.
      return nil if data =~ /^(LINKEDIN|FACEBOOK|TWITTER|INSTAGRAM|YOUTUBE|X):/i
      return nil if data =~ /^(Not found|N\/A|None|Unknown|TBD|Unavailable)/i
      return nil if data.include?('|') # Pipe-separated text leaked into URL field
      return nil unless data =~ /^https?:\/\//i # Must start with http:// or https://
      return nil if data.match?(/\b[A-Z_]+:\s*/i) # Contains field markers like "FIELD_NAME:"

      # Additional validation: check for common social media domains
      valid_url = case data
      when /linkedin\.com/i, /facebook\.com/i, /twitter\.com/i, /x\.com/i,
           /instagram\.com/i, /youtube\.com/i
        data
      else
        nil # URL doesn't match expected social media domains
      end

      Rails.logger.info "Validated URL field: #{valid_url || 'REJECTED'} (original: #{data[0..50]})" if valid_url.nil?
      valid_url

    when :year
      # Validate year founded - must be 4-digit year between 1500-2025
      return nil if data =~ /^(YEAR_FOUNDED|Not found|N\/A|None|Unknown)/i
      return nil if data.include?('|') # Pipe-separated text leaked into year field

      # Extract first 4-digit number
      year_match = data.match(/\b(1[5-9]\d{2}|20[0-2][0-9])\b/)
      validated_year = year_match ? year_match[1] : nil

      Rails.logger.info "Validated year field: #{validated_year || 'REJECTED'} (original: #{data[0..50]})" if validated_year.nil? && data.present?
      validated_year

    when :text
      # Validate text fields - reject field markers and obvious pollution
      return nil if data =~ /^(ADDRESS|HEADQUARTER|BUSINESS_MODEL|OVERVIEW|TAGLINE):/i
      return nil if data =~ /^(DEVELOPMENT_INTERESTS|AREAS_OF_EXPERTISE|SKILLS):/i
      return nil if data == 'Not found' || data == 'N/A' || data == 'None'

      # Check if data looks like a URL (shouldn't be in text fields)
      if data =~ /^https?:\/\//i
        Rails.logger.warn "Rejected text field containing URL: #{data[0..50]}"
        return nil
      end

      # Check if data contains multiple pipe separators (probably leaked from array field)
      if data.scan(/\|/).count >= 3
        Rails.logger.warn "Rejected text field containing pipe-separated values: #{data[0..100]}"
        return nil
      end

      data

    when :pipe_separated
      # Validate pipe-separated array fields
      return nil if data =~ /^(DEVELOPMENT_INTERESTS|AREAS_OF_EXPERTISE|SKILLS|SIMILAR_ORGANIZATIONS):/i
      return nil if data =~ /^(Not found|N\/A|None|Unknown)/i

      # Check if data looks like a URL (shouldn't be in array fields)
      if data =~ /^https?:\/\//i
        Rails.logger.warn "Rejected pipe-separated field containing URL: #{data[0..50]}"
        return nil
      end

      data

    else
      # Unknown field type - return as-is
      data
    end
  end

  # Clean social media URL - returns nil if invalid, cleaned URL otherwise
  # This is a wrapper around validate_extracted_data for backward compatibility
  def clean_social_media_url(url)
    validate_extracted_data(url, :url)
  end

  def company_system_prompt
    <<~PROMPT
      You are an expert business analyst and company profile generator. Your task is to:

      1. Analyze scraped website content from a company
      2. Generate a comprehensive and professional company profile
      3. Extract key business information, metrics, and competitive intelligence
      4. Create engaging descriptions highlighting the company's value proposition
      5. Identify business model, industry, and organizational type
      6. Extract accurate contact information and social media links
      7. Identify similar companies and competitors in the same space

      Always respond using EXACT field markers (NAME:, SHORT_DESCRIPTION:, etc.). Do not use JSON format.

      Focus on:
      - Professional and accurate information extraction
      - Clear, concise descriptions that highlight company strengths
      - Proper categorization of business model and industry
      - Complete contact information including social media
      - Year founded and employee count if available
      - Similar organizations for competitive context
    PROMPT
  end

  def university_system_prompt
    <<~PROMPT
      You are an expert education analyst and university profile generator. Your task is to:

      1. Analyze scraped website content from an educational institution
      2. Generate a comprehensive and professional university/school profile
      3. Extract key academic information, statistics, and competitive context
      4. Create engaging descriptions highlighting educational strengths
      5. Identify institution type, founding year, and academic focus
      6. Extract accurate contact information and social media links
      7. Identify similar institutions and peer schools
      8. Extract student information if available

      Always respond using EXACT field markers (NAME:, SHORT_DESCRIPTION:, etc.). Do not use JSON format.

      Focus on:
      - Professional and accurate information extraction
      - Clear descriptions of academic mission and strengths
      - Student and employee statistics if available
      - Complete contact information including social media
      - Year founded and institution history
      - Similar institutions for competitive context
    PROMPT
  end

  def build_company_prompt(data, url)
    social_media_info = format_social_media_for_prompt(data[:social_media])

    <<~PROMPT
      Please analyze this company website data and generate a structured company profile:

      WEBSITE URL: #{url}
      TITLE: #{data[:title]}
      META DESCRIPTION: #{data[:meta_description]}
      MAIN HEADINGS: #{data[:headings].join(', ')}
      WEBSITE CONTENT SAMPLE: #{data[:raw_text][0..3000]}

      EXTRACTED SOCIAL MEDIA LINKS:
      #{social_media_info}

      Please return enhanced data using EXACTLY these field markers:

      NAME: [Company Name - extract from title or headings]

      SHORT_DESCRIPTION: [A compelling 2-3 sentence description highlighting what the company does and its value proposition]

      LONG_DESCRIPTION: [A comprehensive 4-6 paragraph description covering: company history, mission, products/services, target market, competitive advantages, and future vision]

      TAGLINE: [Short mission statement or compelling tagline that captures their essence]

      OVERVIEW: [Executive summary paragraph providing high-level view of the company, what they do, who they serve, and their market position]

      YEAR_FOUNDED: [YYYY - search for "founded", "established", "since", "est." If not found, make reasonable estimate based on context. NEVER leave empty]

      ADDRESS: [Full address or at minimum city/state - check footer, contact sections]

      EMPLOYEES_COUNT: [Choose ONE from: '1-10', '11-50', '51-100', '101-500', '501-1000', '1001-5000', '5001-10000', '10001-50000', '50001+'. Estimate based on company size indicators if not explicitly stated]

      ORGANIZATION_TYPE: [Choose ONE from: 'For Profit', 'Non Profit', 'Bcorp', 'Private For Profit', 'Public For Profit', 'Government Organization', 'Political Organization', 'Academic'. Be precise based on context]

      BUSINESS_MODEL: [Detailed description of business model - e.g., "B2B SaaS subscription", "E-commerce retail", "Consulting services"]

      LINKEDIN:
      (Provide ONLY the complete URL or leave this line blank)
      (Example: https://linkedin.com/company/example)
      (DO NOT write "LINKEDIN:", "FACEBOOK:", "Not found", or any other text)

      FACEBOOK:
      (Provide ONLY the complete URL or leave this line blank)
      (Example: https://facebook.com/companyname)
      (DO NOT write "FACEBOOK:", "TWITTER:", "Not found", or any other text)

      TWITTER:
      (Provide ONLY the complete URL or leave this line blank)
      (Example: https://twitter.com/handle OR https://x.com/handle)
      (DO NOT write "TWITTER:", "INSTAGRAM:", "Not found", or any other text)

      INSTAGRAM:
      (Provide ONLY the complete URL or leave this line blank)
      (Example: https://instagram.com/username)
      (DO NOT write "INSTAGRAM:", "YOUTUBE:", "Not found", or any other text)

      YOUTUBE:
      (Provide ONLY the complete URL or leave this line blank)
      (Example: https://youtube.com/@channel)
      (DO NOT write "YOUTUBE:", "DEVELOPMENT_INTERESTS:", "Not found", or any other text)

      DEVELOPMENT_INTERESTS: [Generate 5 specific development interests based on services, mission, industry focus - format as: Interest 1 | Interest 2 | Interest 3 | Interest 4 | Interest 5]

      AREAS_OF_EXPERTISE: [Identify 4 distinct areas of expertise based on industry and core competencies - format as: Expertise 1 | Expertise 2 | Expertise 3 | Expertise 4]

      SKILLS: [List 6 specific skills/capabilities - format as: Skill 1 | Skill 2 | Skill 3 | Skill 4 | Skill 5 | Skill 6]

      HEADQUARTER: [Primary headquarters location - city, state/country]

      GROWTH_STAGE: [Choose ONE from: 'Large Enterprise', 'Established Startup', 'Pre-Revenue Startup', 'Small Business', 'Medium Business', 'High-Growth Startup'. Base on company size and maturity]

      SIMILAR_ORGANIZATIONS: [List 3-5 similar companies, direct competitors, or organizations in the same industry/space. Include well-known names that operate in similar markets or provide comparable products/services. Format as: Company 1 | Company 2 | Company 3 | Company 4 | Company 5]

      CRITICAL INSTRUCTIONS:
      1. Use EXACT field markers as shown above (NAME:, SHORT_DESCRIPTION:, etc.)
      2. For descriptions, write in full sentences and paragraphs
      3. For multi-value fields (DEVELOPMENT_INTERESTS, AREAS_OF_EXPERTISE, SKILLS), separate with pipe (|)
      4. For enum fields (ORGANIZATION_TYPE, EMPLOYEES_COUNT, GROWTH_STAGE), use EXACT values provided
      5. Make intelligent inferences when data isn't explicitly available
      6. Write SHORT_DESCRIPTION, LONG_DESCRIPTION, TAGLINE, and OVERVIEW as flowing text (will be converted to HTML)
      7. For social media fields (LINKEDIN, FACEBOOK, TWITTER, INSTAGRAM, YOUTUBE): ONLY provide complete URLs starting with https://. NEVER write field markers, placeholder text, or "Not found". Leave the line completely blank if no URL is available
    PROMPT
  end

  def build_university_prompt(data, url)
    social_media_info = format_social_media_for_prompt(data[:social_media])

    <<~PROMPT
      Please analyze this educational institution website data and generate a structured university profile:

      WEBSITE URL: #{url}
      TITLE: #{data[:title]}
      META DESCRIPTION: #{data[:meta_description]}
      MAIN HEADINGS: #{data[:headings].join(', ')}
      WEBSITE CONTENT SAMPLE: #{data[:raw_text][0..3000]}

      EXTRACTED SOCIAL MEDIA LINKS:
      #{social_media_info}

      Please return enhanced data using EXACTLY these field markers:

      NAME: [University/School Name - extract from title or headings]

      SHORT_DESCRIPTION: [A compelling 2-3 sentence description highlighting the institution's academic focus, history, and distinguishing characteristics]

      LONG_DESCRIPTION: [A comprehensive 4-6 paragraph description covering: institution history, academic mission, programs offered, research focus, student body, campus culture, and community impact]

      TAGLINE: [School mission statement, motto, or compelling tagline that captures their educational philosophy]

      OVERVIEW: [Executive summary paragraph providing high-level view of the institution, its academic offerings, student demographics, and educational approach]

      YEAR_FOUNDED: [YYYY - search for "founded", "established", "since", charter date. If not found, make reasonable estimate. NEVER leave empty]

      ADDRESS: [Full campus address or at minimum city/state - check footer, contact sections]

      EMPLOYEES_COUNT: [Choose ONE from: '1-10', '11-50', '51-100', '101-500', '501-1000', '1001-5000', '5001-10000', '10001-50000', '50001+'. Estimate faculty/staff count based on institution size]

      ORGANIZATION_TYPE: [Choose ONE from: 'For Profit', 'Non Profit', 'Bcorp', 'Private For Profit', 'Public For Profit', 'Government Organization', 'Political Organization', 'Academic'. Most schools will be 'Academic']

      ADMINISTRATORS: [Names of key administrators - President, Chancellor, Dean, Provost. Search leadership sections. Format as: Title: Name | Title: Name]

      LINKEDIN:
      (Provide ONLY the complete URL or leave this line blank)
      (Example: https://linkedin.com/company/example)
      (DO NOT write "LINKEDIN:", "FACEBOOK:", "Not found", or any other text)

      FACEBOOK:
      (Provide ONLY the complete URL or leave this line blank)
      (Example: https://facebook.com/companyname)
      (DO NOT write "FACEBOOK:", "TWITTER:", "Not found", or any other text)

      TWITTER:
      (Provide ONLY the complete URL or leave this line blank)
      (Example: https://twitter.com/handle OR https://x.com/handle)
      (DO NOT write "TWITTER:", "INSTAGRAM:", "Not found", or any other text)

      INSTAGRAM:
      (Provide ONLY the complete URL or leave this line blank)
      (Example: https://instagram.com/username)
      (DO NOT write "INSTAGRAM:", "YOUTUBE:", "Not found", or any other text)

      YOUTUBE:
      (Provide ONLY the complete URL or leave this line blank)
      (Example: https://youtube.com/@channel)
      (DO NOT write "YOUTUBE:", "DEVELOPMENT_INTERESTS:", "Not found", or any other text)

      DEVELOPMENT_INTERESTS: [Generate 5 specific development interests based on academic programs, research areas, strategic goals - format as: Interest 1 | Interest 2 | Interest 3 | Interest 4 | Interest 5]

      AREAS_OF_EXPERTISE: [Identify 4 distinct areas of expertise based on academic strengths and programs - format as: Expertise 1 | Expertise 2 | Expertise 3 | Expertise 4]

      SKILLS: [List 6 specific institutional capabilities and strengths - format as: Skill 1 | Skill 2 | Skill 3 | Skill 4 | Skill 5 | Skill 6]

      HEADQUARTER: [Main campus location - city, state/country]

      SIMILAR_ORGANIZATIONS: [List 3-5 similar universities, colleges, or educational institutions. Include peer institutions, competitors for students, or schools with similar academic focus. Format as: Institution 1 | Institution 2 | Institution 3 | Institution 4 | Institution 5]

      STUDENT_INFO: [If available: enrollment numbers, student-faculty ratio, graduation rates, or other student demographic information. Leave blank if not found]

      CRITICAL INSTRUCTIONS:
      1. Use EXACT field markers as shown above (NAME:, SHORT_DESCRIPTION:, etc.)
      2. For descriptions, write in full sentences and paragraphs
      3. For multi-value fields (DEVELOPMENT_INTERESTS, AREAS_OF_EXPERTISE, SKILLS, ADMINISTRATORS), separate with pipe (|)
      4. For enum fields (ORGANIZATION_TYPE, EMPLOYEES_COUNT), use EXACT values provided
      5. Make intelligent inferences when data isn't explicitly available
      6. Write SHORT_DESCRIPTION, LONG_DESCRIPTION, TAGLINE, and OVERVIEW as flowing text (will be converted to HTML)
      7. For social media fields (LINKEDIN, FACEBOOK, TWITTER, INSTAGRAM, YOUTUBE): ONLY provide complete URLs starting with https://. NEVER write field markers, placeholder text, or "Not found". Leave the line completely blank if no URL is available
    PROMPT
  end

  def merge_company_data(scraped_data, content, url)
    # Extract fields using AiParsingHelpers
    name = extract_field(content, 'NAME')
    short_description = extract_field(content, 'SHORT_DESCRIPTION')
    long_description = extract_field(content, 'LONG_DESCRIPTION')
    tagline = extract_field(content, 'TAGLINE')
    overview = extract_field(content, 'OVERVIEW')

    # Extract and validate year_founded
    year_founded = validate_extracted_data(extract_field(content, 'YEAR_FOUNDED'), :year)

    # Extract and validate text fields
    address = validate_extracted_data(extract_field(content, 'ADDRESS'), :text)
    employees_count = extract_field(content, 'EMPLOYEES_COUNT')
    organization_type = extract_field(content, 'ORGANIZATION_TYPE')
    business_model = validate_extracted_data(extract_field(content, 'BUSINESS_MODEL'), :text)
    headquarter = validate_extracted_data(extract_field(content, 'HEADQUARTER'), :text)
    growth_stage = extract_field(content, 'GROWTH_STAGE')

    # Extract social media and validate URLs
    # Log raw values BEFORE validation
    linkedin_raw = extract_field(content, 'LINKEDIN')
    facebook_raw = extract_field(content, 'FACEBOOK')
    twitter_raw = extract_field(content, 'TWITTER')
    instagram_raw = extract_field(content, 'INSTAGRAM')
    youtube_raw = extract_field(content, 'YOUTUBE')

    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [COMPANY] Raw social media values BEFORE validation:"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [COMPANY]   LinkedIn (raw): #{linkedin_raw.inspect}"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [COMPANY]   Facebook (raw): #{facebook_raw.inspect}"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [COMPANY]   Twitter (raw): #{twitter_raw.inspect}"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [COMPANY]   Instagram (raw): #{instagram_raw.inspect}"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [COMPANY]   YouTube (raw): #{youtube_raw.inspect}"

    # Validate URLs
    linkedin = validate_extracted_data(linkedin_raw, :url)
    facebook = validate_extracted_data(facebook_raw, :url)
    twitter = validate_extracted_data(twitter_raw, :url)
    instagram = validate_extracted_data(instagram_raw, :url)
    youtube = validate_extracted_data(youtube_raw, :url)

    # Log cleaned values AFTER validation
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [COMPANY] Cleaned social media values AFTER validation:"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [COMPANY]   LinkedIn (cleaned): #{linkedin.inspect}"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [COMPANY]   Facebook (cleaned): #{facebook.inspect}"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [COMPANY]   Twitter (cleaned): #{twitter.inspect}"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [COMPANY]   Instagram (cleaned): #{instagram.inspect}"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [COMPANY]   YouTube (cleaned): #{youtube.inspect}"

    # Log rejected values
    Rails.logger.warn "SOCIAL_MEDIA_DEBUG: [COMPANY] REJECTED - LinkedIn: '#{linkedin_raw}'" if linkedin_raw.present? && linkedin.nil?
    Rails.logger.warn "SOCIAL_MEDIA_DEBUG: [COMPANY] REJECTED - Facebook: '#{facebook_raw}'" if facebook_raw.present? && facebook.nil?
    Rails.logger.warn "SOCIAL_MEDIA_DEBUG: [COMPANY] REJECTED - Twitter: '#{twitter_raw}'" if twitter_raw.present? && twitter.nil?
    Rails.logger.warn "SOCIAL_MEDIA_DEBUG: [COMPANY] REJECTED - Instagram: '#{instagram_raw}'" if instagram_raw.present? && instagram.nil?
    Rails.logger.warn "SOCIAL_MEDIA_DEBUG: [COMPANY] REJECTED - YouTube: '#{youtube_raw}'" if youtube_raw.present? && youtube.nil?

    # Extract and validate pipe-separated fields
    development_interests_raw = validate_extracted_data(extract_field(content, 'DEVELOPMENT_INTERESTS'), :pipe_separated)
    development_interests = development_interests_raw&.split('|')&.map(&:strip) || []

    areas_of_expertise_raw = validate_extracted_data(extract_field(content, 'AREAS_OF_EXPERTISE'), :pipe_separated)
    areas_of_expertise = areas_of_expertise_raw&.split('|')&.map(&:strip) || []

    skills_raw = validate_extracted_data(extract_field(content, 'SKILLS'), :pipe_separated)
    skills = skills_raw&.split('|')&.map(&:strip) || []

    # Extract comprehensive details with validation
    similar_organizations_raw = validate_extracted_data(extract_field(content, 'SIMILAR_ORGANIZATIONS'), :pipe_separated)
    similar_organizations = similar_organizations_raw&.split('|')&.map(&:strip) || []

    # Map organization type to enum value
    org_type_mapped = map_organization_type(organization_type)

    # Map employees count to enum value
    employees_count_mapped = map_employees_count(employees_count)

    # Map growth stage to enum value
    growth_stage_mapped = map_growth_stage(growth_stage)

    # Format descriptions as HTML
    short_description_html = short_description.present? ? text_to_html_paragraphs(short_description) : ""
    long_description_html = long_description.present? ? text_to_html_paragraphs(long_description) : ""
    tagline_html = tagline.present? ? text_to_html_paragraphs(tagline) : ""
    overview_html = overview.present? ? text_to_html_paragraphs(overview) : ""

    {
      partner: {
        name: name || scraped_data[:title],
        website: url,
        address: address || scraped_data[:contact_info][:addresses]&.first,
        year_founded: year_founded&.to_i,
        category: 'company',
        organization_type: org_type_mapped,
        employees_count: employees_count_mapped,
        short_description: short_description_html,
        long_description: long_description_html,
        tagline: tagline_html,
        overview: overview_html,
        linkedin: linkedin.presence,
        facebook: facebook.presence,
        twitter: twitter.presence,
        youtube: youtube.presence,
        instagram: instagram.presence,
        business_model: business_model
      },
      company_detail: {
        headquarter: headquarter,
        growth_stage: growth_stage_mapped
      },
      tags: {
        development_interests: development_interests,
        areas_of_expertise: areas_of_expertise,
        skills: skills
      },
      comprehensive_details: {
        similar_organizations: similar_organizations
      },
      departments: []
    }
  end

  def merge_university_data(scraped_data, content, url)
    # Extract fields using AiParsingHelpers
    name = extract_field(content, 'NAME')
    short_description = extract_field(content, 'SHORT_DESCRIPTION')
    long_description = extract_field(content, 'LONG_DESCRIPTION')
    tagline = extract_field(content, 'TAGLINE')
    overview = extract_field(content, 'OVERVIEW')

    # Extract and validate year_founded
    year_founded = validate_extracted_data(extract_field(content, 'YEAR_FOUNDED'), :year)

    # Extract and validate text fields
    address = validate_extracted_data(extract_field(content, 'ADDRESS'), :text)
    employees_count = extract_field(content, 'EMPLOYEES_COUNT')
    organization_type = extract_field(content, 'ORGANIZATION_TYPE')
    administrators = extract_field(content, 'ADMINISTRATORS')
    headquarter = validate_extracted_data(extract_field(content, 'HEADQUARTER'), :text)

    # Extract social media and validate URLs
    # Log raw values BEFORE validation
    linkedin_raw = extract_field(content, 'LINKEDIN')
    facebook_raw = extract_field(content, 'FACEBOOK')
    twitter_raw = extract_field(content, 'TWITTER')
    instagram_raw = extract_field(content, 'INSTAGRAM')
    youtube_raw = extract_field(content, 'YOUTUBE')

    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [UNIVERSITY] Raw social media values BEFORE validation:"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [UNIVERSITY]   LinkedIn (raw): #{linkedin_raw.inspect}"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [UNIVERSITY]   Facebook (raw): #{facebook_raw.inspect}"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [UNIVERSITY]   Twitter (raw): #{twitter_raw.inspect}"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [UNIVERSITY]   Instagram (raw): #{instagram_raw.inspect}"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [UNIVERSITY]   YouTube (raw): #{youtube_raw.inspect}"

    # Validate URLs
    linkedin = validate_extracted_data(linkedin_raw, :url)
    facebook = validate_extracted_data(facebook_raw, :url)
    twitter = validate_extracted_data(twitter_raw, :url)
    instagram = validate_extracted_data(instagram_raw, :url)
    youtube = validate_extracted_data(youtube_raw, :url)

    # Log cleaned values AFTER validation
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [UNIVERSITY] Cleaned social media values AFTER validation:"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [UNIVERSITY]   LinkedIn (cleaned): #{linkedin.inspect}"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [UNIVERSITY]   Facebook (cleaned): #{facebook.inspect}"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [UNIVERSITY]   Twitter (cleaned): #{twitter.inspect}"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [UNIVERSITY]   Instagram (cleaned): #{instagram.inspect}"
    Rails.logger.info "SOCIAL_MEDIA_DEBUG: [UNIVERSITY]   YouTube (cleaned): #{youtube.inspect}"

    # Log rejected values
    Rails.logger.warn "SOCIAL_MEDIA_DEBUG: [UNIVERSITY] REJECTED - LinkedIn: '#{linkedin_raw}'" if linkedin_raw.present? && linkedin.nil?
    Rails.logger.warn "SOCIAL_MEDIA_DEBUG: [UNIVERSITY] REJECTED - Facebook: '#{facebook_raw}'" if facebook_raw.present? && facebook.nil?
    Rails.logger.warn "SOCIAL_MEDIA_DEBUG: [UNIVERSITY] REJECTED - Twitter: '#{twitter_raw}'" if twitter_raw.present? && twitter.nil?
    Rails.logger.warn "SOCIAL_MEDIA_DEBUG: [UNIVERSITY] REJECTED - Instagram: '#{instagram_raw}'" if instagram_raw.present? && instagram.nil?
    Rails.logger.warn "SOCIAL_MEDIA_DEBUG: [UNIVERSITY] REJECTED - YouTube: '#{youtube_raw}'" if youtube_raw.present? && youtube.nil?

    # Extract and validate pipe-separated fields
    development_interests_raw = validate_extracted_data(extract_field(content, 'DEVELOPMENT_INTERESTS'), :pipe_separated)
    development_interests = development_interests_raw&.split('|')&.map(&:strip) || []

    areas_of_expertise_raw = validate_extracted_data(extract_field(content, 'AREAS_OF_EXPERTISE'), :pipe_separated)
    areas_of_expertise = areas_of_expertise_raw&.split('|')&.map(&:strip) || []

    skills_raw = validate_extracted_data(extract_field(content, 'SKILLS'), :pipe_separated)
    skills = skills_raw&.split('|')&.map(&:strip) || []

    # Extract comprehensive details with validation
    similar_organizations_raw = validate_extracted_data(extract_field(content, 'SIMILAR_ORGANIZATIONS'), :pipe_separated)
    similar_organizations = similar_organizations_raw&.split('|')&.map(&:strip) || []

    student_info = validate_extracted_data(extract_field(content, 'STUDENT_INFO'), :text)

    # Map organization type to enum value
    org_type_mapped = map_organization_type(organization_type)

    # Map employees count to enum value
    employees_count_mapped = map_employees_count(employees_count)

    # Format descriptions as HTML
    short_description_html = short_description.present? ? text_to_html_paragraphs(short_description) : ""
    long_description_html = long_description.present? ? text_to_html_paragraphs(long_description) : ""
    tagline_html = tagline.present? ? text_to_html_paragraphs(tagline) : ""
    overview_html = overview.present? ? text_to_html_paragraphs(overview) : ""
    student_info_html = student_info.present? ? text_to_html_paragraphs(student_info) : ""

    {
      partner: {
        name: name || scraped_data[:title],
        website: url,
        address: address || scraped_data[:contact_info][:addresses]&.first,
        year_founded: year_founded&.to_i,
        category: 'school',
        organization_type: org_type_mapped,
        employees_count: employees_count_mapped,
        short_description: short_description_html,
        long_description: long_description_html,
        tagline: tagline_html,
        overview: overview_html,
        linkedin: linkedin.presence,
        facebook: facebook.presence,
        twitter: twitter.presence,
        youtube: youtube.presence,
        instagram: instagram.presence,
        business_model: nil
      },
      company_detail: {
        headquarter: headquarter,
        administrators: administrators
      },
      tags: {
        development_interests: development_interests,
        areas_of_expertise: areas_of_expertise,
        skills: skills
      },
      comprehensive_details: {
        similar_organizations: similar_organizations,
        student_info: student_info_html
      },
      departments: []
    }
  end

  def basic_company_profile(scraped_data, url)
    social_media = extract_social_media(scraped_data)
    description = scraped_data[:meta_description] || scraped_data[:paragraphs]&.first || ""
    description_html = description.present? ? text_to_html_paragraphs(description) : ""

    {
      partner: {
        name: scraped_data[:title],
        website: url,
        address: scraped_data[:contact_info][:addresses]&.first,
        year_founded: nil,
        category: 'company',
        organization_type: 'For Profit',
        employees_count: nil,
        short_description: description_html,
        long_description: "",
        tagline: "",
        overview: "",
        linkedin: social_media["linkedin"],
        facebook: social_media["facebook"],
        twitter: social_media["twitter"],
        youtube: social_media["youtube"],
        instagram: social_media["instagram"],
        business_model: ""
      },
      company_detail: {
        headquarter: nil,
        growth_stage: nil
      },
      tags: {
        development_interests: [],
        areas_of_expertise: [],
        skills: []
      },
      departments: []
    }
  end

  def basic_university_profile(scraped_data, url)
    social_media = extract_social_media(scraped_data)
    description = scraped_data[:meta_description] || scraped_data[:paragraphs]&.first || ""
    description_html = description.present? ? text_to_html_paragraphs(description) : ""

    {
      partner: {
        name: scraped_data[:title],
        website: url,
        address: scraped_data[:contact_info][:addresses]&.first,
        year_founded: nil,
        category: 'school',
        organization_type: 'Academic',
        employees_count: nil,
        short_description: description_html,
        long_description: "",
        tagline: "",
        overview: "",
        linkedin: social_media["linkedin"],
        facebook: social_media["facebook"],
        twitter: social_media["twitter"],
        youtube: social_media["youtube"],
        instagram: social_media["instagram"],
        business_model: nil
      },
      company_detail: {
        headquarter: nil,
        administrators: nil
      },
      tags: {
        development_interests: [],
        areas_of_expertise: [],
        skills: []
      },
      departments: []
    }
  end

  def format_social_media_for_prompt(social_media)
    return "None found" if social_media.blank?

    lines = []
    lines << "Use these URLs EXACTLY as shown below. Copy the full URL for each platform."
    lines << ""
    lines << "LINKEDIN: #{social_media[:linkedin]}" if social_media[:linkedin].present?
    lines << "FACEBOOK: #{social_media[:facebook]}" if social_media[:facebook].present?
    lines << "TWITTER: #{social_media[:twitter]}" if social_media[:twitter].present?
    lines << "INSTAGRAM: #{social_media[:instagram]}" if social_media[:instagram].present?
    lines << "YOUTUBE: #{social_media[:youtube]}" if social_media[:youtube].present?

    lines.any? ? lines.join("\n") : "None found"
  end

  def extract_social_media(scraped_data)
    # First, try to use the pre-extracted social media links from scraper
    if scraped_data[:social_media].present?
      return {
        "linkedin" => scraped_data[:social_media][:linkedin],
        "facebook" => scraped_data[:social_media][:facebook],
        "twitter" => scraped_data[:social_media][:twitter],
        "instagram" => scraped_data[:social_media][:instagram],
        "youtube" => scraped_data[:social_media][:youtube]
      }
    end

    # Fallback: extract from links if social_media not available
    social = {
      "linkedin" => nil,
      "facebook" => nil,
      "twitter" => nil,
      "instagram" => nil,
      "youtube" => nil
    }

    scraped_data[:links]&.each do |link|
      href = link[:href]
      social["linkedin"] = href if href =~ /linkedin\.com\/(company|school|showcase)/i && social["linkedin"].nil?
      social["facebook"] = href if href =~ /facebook\.com/i && social["facebook"].nil?
      social["twitter"] = href if href =~ /(twitter\.com|x\.com)/i && social["twitter"].nil?
      social["instagram"] = href if href =~ /instagram\.com/i && social["instagram"].nil?
      social["youtube"] = href if href =~ /youtube\.com/i && social["youtube"].nil?
    end

    social
  end

  # Map organization type string to Partner enum value
  def map_organization_type(org_type_str)
    return 'For Profit' if org_type_str.blank?

    org_type_str = org_type_str.strip

    # Exact matches
    valid_types = ['For Profit', 'Non Profit', 'Bcorp', 'Private For Profit', 'Public For Profit',
                   'Government Organization', 'Political Organization', 'Academic']

    return org_type_str if valid_types.include?(org_type_str)

    # Fuzzy matching
    case org_type_str.downcase
    when /private.*profit|llc|partnership/i
      'Private For Profit'
    when /public.*profit|corporation|public.*company/i
      'Public For Profit'
    when /non.*profit|nonprofit/i
      'Non Profit'
    when /bcorp|b corp|benefit/i
      'Bcorp'
    when /government|gov/i
      'Government Organization'
    when /political/i
      'Political Organization'
    when /academic|university|college|school|education/i
      'Academic'
    else
      'For Profit' # Default
    end
  end

  # Map employees count string to Partner enum value
  def map_employees_count(count_str)
    return nil if count_str.blank?

    count_str = count_str.strip

    # Exact matches
    valid_counts = ['1-10', '11-50', '51-100', '101-500', '501-1000', '1001-5000',
                    '5001-10000', '10001-50000', '50001+']

    return count_str if valid_counts.include?(count_str)

    # Extract numeric values for range matching
    numbers = count_str.scan(/\d+/).map(&:to_i)
    return nil if numbers.empty?

    max_number = numbers.max

    case max_number
    when 0..10
      '1-10'
    when 11..50
      '11-50'
    when 51..100
      '51-100'
    when 101..500
      '101-500'
    when 501..1000
      '501-1000'
    when 1001..5000
      '1001-5000'
    when 5001..10000
      '5001-10000'
    when 10001..50000
      '10001-50000'
    else
      '50001+'
    end
  end

  # Map growth stage string to CompanyDetail enum value
  def map_growth_stage(stage_str)
    return nil if stage_str.blank?

    stage_str = stage_str.strip

    # Exact matches
    valid_stages = ['Large Enterprise', 'Established Startup', 'Pre-Revenue Startup',
                    'Small Business', 'Medium Business', 'High-Growth Startup']

    return stage_str if valid_stages.include?(stage_str)

    # Fuzzy matching
    case stage_str.downcase
    when /large.*enterprise|enterprise/i
      'Large Enterprise'
    when /established.*startup/i
      'Established Startup'
    when /pre.*revenue|early.*stage/i
      'Pre-Revenue Startup'
    when /small.*business/i
      'Small Business'
    when /medium.*business/i
      'Medium Business'
    when /high.*growth|growth.*startup/i
      'High-Growth Startup'
    else
      nil
    end
  end
end

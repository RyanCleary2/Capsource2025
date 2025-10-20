require 'openai'

class OpenaiOrganizationEnhancer
  def initialize
    @client = OpenAI::Client.new(
      access_token: ENV['OPENAI_API_KEY'],
      organization_id: ENV['OPENAI_ORGANIZATION_ID'] # Optional
    )
  end

  def enhance_company_profile(scraped_data, url)
    Rails.logger.info "Enhancing company profile with OpenAI..."

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

      ai_data = JSON.parse(response.dig('choices', 0, 'message', 'content'))
      merge_company_data(scraped_data, ai_data, url)

    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse OpenAI response: #{e.message}"
      basic_company_profile(scraped_data, url)
    rescue => e
      Rails.logger.error "OpenAI API error: #{e.message}"
      basic_company_profile(scraped_data, url)
    end
  end

  def enhance_university_profile(scraped_data, url)
    Rails.logger.info "Enhancing university profile with OpenAI..."

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

      ai_data = JSON.parse(response.dig('choices', 0, 'message', 'content'))
      merge_university_data(scraped_data, ai_data, url)

    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse OpenAI response: #{e.message}"
      basic_university_profile(scraped_data, url)
    rescue => e
      Rails.logger.error "OpenAI API error: #{e.message}"
      basic_university_profile(scraped_data, url)
    end
  end

  private

  def company_system_prompt
    <<~PROMPT
      You are an expert business analyst and company profile generator. Your task is to:

      1. Analyze scraped website content from a company
      2. Generate a comprehensive and professional company profile
      3. Extract key business information and metrics
      4. Create engaging descriptions highlighting the company's value proposition
      5. Identify business model, industry, and organizational type
      6. Extract accurate contact information and social media links

      Always respond with valid JSON in the exact format requested. Do not include any text outside the JSON structure.

      Focus on:
      - Professional and accurate information extraction
      - Clear, concise descriptions that highlight company strengths
      - Proper categorization of business model and industry
      - Complete contact information including social media
      - Year founded and employee count if available
    PROMPT
  end

  def university_system_prompt
    <<~PROMPT
      You are an expert education analyst and university profile generator. Your task is to:

      1. Analyze scraped website content from an educational institution
      2. Generate a comprehensive and professional university/school profile
      3. Extract key academic information and statistics
      4. Create engaging descriptions highlighting educational strengths
      5. Identify institution type, founding year, and academic focus
      6. Extract accurate contact information and social media links

      Always respond with valid JSON in the exact format requested. Do not include any text outside the JSON structure.

      Focus on:
      - Professional and accurate information extraction
      - Clear descriptions of academic offerings and mission
      - Student and employee statistics if available
      - Complete contact information including social media
      - Year founded and institution history
    PROMPT
  end

  def build_company_prompt(data, url)
    <<~PROMPT
      Please analyze this company website data and generate a structured company profile:

      WEBSITE URL: #{url}
      TITLE: #{data[:title]}
      META DESCRIPTION: #{data[:meta_description]}
      MAIN HEADINGS: #{data[:headings].join(', ')}
      WEBSITE CONTENT SAMPLE: #{data[:raw_text][0..3000]}

      Please return enhanced data in this EXACT JSON format:
      {
        "name": "Company Name",
        "description": "A compelling 2-3 sentence description highlighting what the company does and its value proposition",
        "website": "#{url}",
        "yearFounded": "YYYY or null if unknown",
        "address": "Full address or null",
        "numberOfEmployees": "Number or range (e.g., '50-100') or null",
        "businessModel": "Description of business model",
        "organizationType": "Type of organization (e.g., Public For Profit, Private Company, Non-Profit, etc.)",
        "tagline": "Short mission or tagline",
        "socialMedia": {
          "linkedin": "LinkedIn URL or null",
          "facebook": "Facebook URL or null",
          "twitter": "Twitter/X URL or null",
          "instagram": "Instagram URL or null",
          "youtube": "YouTube URL or null"
        },
        "developmentInterests": ["Interest 1", "Interest 2", "Interest 3", "Interest 4", "Interest 5"],
        "areasOfExpertise": ["Expertise 1", "Expertise 2", "Expertise 3", "Expertise 4"],
        "skills": ["Skill 1", "Skill 2", "Skill 3", "Skill 4", "Skill 5", "Skill 6"]
      }

      CRITICAL INSTRUCTIONS - EVERY FIELD MUST BE FILLED:
      1. Extract the company name from the title or headings - REQUIRED
      2. Create a detailed, professional 2-3 sentence description based on the content - REQUIRED
      3. Identify year founded if mentioned (search for "founded", "established", "since", "est.", copyright years). If not explicitly stated, make a reasonable estimate based on the website content, domain age context, or industry presence. NEVER return null - provide your best estimate.
      4. Extract complete address if available (check footer, contact sections). If partial address found, include city/state at minimum. If no address, research typical location from the domain or company context.
      5. Extract or intelligently estimate employee count. Look for "team", "staff", "employees" mentions. If not found, estimate based on company size indicators, office locations, or industry standards. Use ranges like "1-10", "10-50", "50-200", "200-500", "500+". NEVER return null.
      6. Describe the business model in detail based on what they do (e.g., "B2B SaaS subscription model", "E-commerce retail", "Consulting services", "Manufacturing and distribution") - REQUIRED
      7. Categorize the organization type appropriately (e.g., "Private For-Profit Company", "Public Corporation", "Non-Profit Organization", "LLC", "Partnership") - REQUIRED
      8. Create a compelling tagline from their mission/about content or main value proposition - REQUIRED
      9. Search thoroughly for ALL social media URLs in the content. Check footers, headers, and embedded links - EXTRACT EVERY AVAILABLE PLATFORM
      10. Generate 5 specific development interests based on their services, mission, industry focus, and market positioning (e.g., "Digital Transformation", "Customer Experience", "Market Expansion", "Product Innovation", "Sustainable Growth") - MUST HAVE 5 ITEMS
      11. Identify 4 distinct areas of expertise based on their industry, core competencies, and service offerings (e.g., "Financial Services", "Technology Solutions", "Supply Chain Management", "Human Capital Development") - MUST HAVE 4 ITEMS
      12. List 6 specific skills/capabilities based on what they offer and do (e.g., "Data Analytics", "Strategic Consulting", "Cloud Infrastructure", "UX Design", "Risk Management", "Change Management") - MUST HAVE 6 ITEMS

      IMPORTANT: Be thorough, detailed, and comprehensive. Make intelligent inferences when exact data isn't available. NEVER leave fields as null unless absolutely impossible to determine. Use the content, context, and industry knowledge to fill every field with meaningful, accurate information.
    PROMPT
  end

  def build_university_prompt(data, url)
    <<~PROMPT
      Please analyze this educational institution website data and generate a structured university profile:

      WEBSITE URL: #{url}
      TITLE: #{data[:title]}
      META DESCRIPTION: #{data[:meta_description]}
      MAIN HEADINGS: #{data[:headings].join(', ')}
      WEBSITE CONTENT SAMPLE: #{data[:raw_text][0..3000]}

      Please return enhanced data in this EXACT JSON format:
      {
        "name": "University/School Name",
        "description": "A compelling 2-3 sentence description highlighting the institution's academic focus, history, and distinguishing characteristics",
        "website": "#{url}",
        "yearFounded": "YYYY or null if unknown",
        "address": "Full address or null",
        "numberOfStudents": "Number or range or null",
        "numberOfEmployees": "Number or range of faculty/staff or null",
        "organizationType": "Type of institution (e.g., Public University, Private University, Community College, etc.)",
        "tagline": "School mission or tagline",
        "administrators": "Name of key administrator (President, Chancellor, etc.) or null",
        "socialMedia": {
          "linkedin": "LinkedIn URL or null",
          "facebook": "Facebook URL or null",
          "twitter": "Twitter/X URL or null",
          "instagram": "Instagram URL or null",
          "youtube": "YouTube URL or null"
        },
        "developmentInterests": ["Interest 1", "Interest 2", "Interest 3", "Interest 4", "Interest 5"],
        "areasOfExpertise": ["Expertise 1", "Expertise 2", "Expertise 3", "Expertise 4"],
        "skills": ["Skill 1", "Skill 2", "Skill 3", "Skill 4", "Skill 5", "Skill 6"]
      }

      CRITICAL INSTRUCTIONS - EVERY FIELD MUST BE FILLED:
      1. Extract the institution name from the title or headings - REQUIRED
      2. Create a detailed, professional 2-3 sentence description highlighting academic focus, history, and unique characteristics - REQUIRED
      3. Identify founding year if mentioned (search for "founded", "established", "since", "est.", charter date, incorporation date). If not explicitly stated, make a reasonable estimate based on institutional history context, building dates, or typical founding periods for similar institutions. NEVER return null - provide your best estimate.
      4. Extract complete address if available (check footer, contact sections, campus location). If partial address found, include city/state at minimum. Campus addresses are usually prominently displayed.
      5. Extract or estimate student enrollment numbers. Look for "students", "enrollment", "undergraduate", "graduate" mentions. If not found, estimate based on institution size indicators (campus size, number of programs, facilities mentioned). Use ranges like "1,000-2,000", "5,000-10,000", "10,000+". NEVER return null.
      6. Extract or estimate faculty/staff count. Look for "faculty", "professors", "staff", "employees" mentions. If not found, estimate based on student-to-faculty ratios (typically 10-20:1) or institution size. Use ranges like "100-200", "500-1,000", "1,000+". NEVER return null.
      7. Categorize the institution type precisely (e.g., "Public Research University", "Private Liberal Arts College", "Community College", "Technical Institute", "Graduate School") - REQUIRED
      8. Create a compelling tagline from their mission statement, motto, or core educational philosophy - REQUIRED
      9. Extract key administrator names if mentioned (President, Chancellor, Dean, Provost). Search "leadership", "administration", "about" sections.
      10. Search thoroughly for ALL social media URLs. Educational institutions typically have active social media presence - check footers, headers, and contact pages - EXTRACT EVERY AVAILABLE PLATFORM
      11. Generate 5 specific development interests based on academic programs, research areas, community initiatives, and strategic goals (e.g., "STEM Education", "Community Partnerships", "Research Innovation", "Global Learning", "Career Readiness") - MUST HAVE 5 ITEMS
      12. Identify 4 distinct areas of expertise based on academic strengths, notable programs, and research focus (e.g., "Engineering & Technology", "Health Sciences", "Business Administration", "Liberal Arts & Humanities") - MUST HAVE 4 ITEMS
      13. List 6 specific institutional capabilities and strengths (e.g., "Online Learning", "Research Excellence", "Industry Partnerships", "Student Success Programs", "Diversity & Inclusion", "Career Services") - MUST HAVE 6 ITEMS

      IMPORTANT: Be thorough, detailed, and comprehensive. Educational institutions typically have rich information available. Make intelligent inferences when exact data isn't available. NEVER leave fields as null unless absolutely impossible to determine. Use the content, context, and higher education knowledge to fill every field with meaningful, accurate information.
    PROMPT
  end

  def merge_company_data(scraped_data, ai_data, url)
    {
      "name" => ai_data["name"] || scraped_data[:title],
      "description" => ai_data["description"] || "",
      "website" => url,
      "yearFounded" => ai_data["yearFounded"],
      "address" => ai_data["address"] || scraped_data[:contact_info][:addresses]&.first,
      "numberOfEmployees" => ai_data["numberOfEmployees"],
      "businessModel" => ai_data["businessModel"] || "",
      "organizationType" => ai_data["organizationType"] || "Company",
      "tagline" => ai_data["tagline"] || "",
      "socialMedia" => ai_data["socialMedia"] || {},
      "developmentInterests" => ai_data["developmentInterests"] || [],
      "areasOfExpertise" => ai_data["areasOfExpertise"] || [],
      "skills" => ai_data["skills"] || [],
      "logoUrl" => extract_logo_url(scraped_data),
      "bannerUrl" => nil
    }
  end

  def merge_university_data(scraped_data, ai_data, url)
    {
      "name" => ai_data["name"] || scraped_data[:title],
      "description" => ai_data["description"] || "",
      "website" => url,
      "yearFounded" => ai_data["yearFounded"],
      "address" => ai_data["address"] || scraped_data[:contact_info][:addresses]&.first,
      "numberOfStudents" => ai_data["numberOfStudents"],
      "numberOfEmployees" => ai_data["numberOfEmployees"],
      "organizationType" => ai_data["organizationType"] || "University",
      "tagline" => ai_data["tagline"] || "",
      "administrators" => ai_data["administrators"],
      "socialMedia" => ai_data["socialMedia"] || {},
      "developmentInterests" => ai_data["developmentInterests"] || [],
      "areasOfExpertise" => ai_data["areasOfExpertise"] || [],
      "skills" => ai_data["skills"] || [],
      "logoUrl" => extract_logo_url(scraped_data),
      "bannerUrl" => nil
    }
  end

  def basic_company_profile(scraped_data, url)
    {
      "name" => scraped_data[:title],
      "description" => scraped_data[:meta_description] || scraped_data[:paragraphs]&.first || "",
      "website" => url,
      "yearFounded" => nil,
      "address" => scraped_data[:contact_info][:addresses]&.first,
      "numberOfEmployees" => nil,
      "businessModel" => "",
      "organizationType" => "Company",
      "tagline" => "",
      "socialMedia" => extract_social_media(scraped_data),
      "logoUrl" => nil,
      "bannerUrl" => nil
    }
  end

  def basic_university_profile(scraped_data, url)
    {
      "name" => scraped_data[:title],
      "description" => scraped_data[:meta_description] || scraped_data[:paragraphs]&.first || "",
      "website" => url,
      "yearFounded" => nil,
      "address" => scraped_data[:contact_info][:addresses]&.first,
      "numberOfStudents" => nil,
      "numberOfEmployees" => nil,
      "organizationType" => "University",
      "tagline" => "",
      "administrators" => nil,
      "socialMedia" => extract_social_media(scraped_data),
      "logoUrl" => nil,
      "bannerUrl" => nil
    }
  end

  def extract_social_media(scraped_data)
    social = {
      "linkedin" => nil,
      "facebook" => nil,
      "twitter" => nil,
      "instagram" => nil,
      "youtube" => nil
    }

    scraped_data[:links]&.each do |link|
      href = link[:href]
      social["linkedin"] = href if href =~ /linkedin\.com/i && social["linkedin"].nil?
      social["facebook"] = href if href =~ /facebook\.com/i && social["facebook"].nil?
      social["twitter"] = href if href =~ /(twitter\.com|x\.com)/i && social["twitter"].nil?
      social["instagram"] = href if href =~ /instagram\.com/i && social["instagram"].nil?
      social["youtube"] = href if href =~ /youtube\.com/i && social["youtube"].nil?
    end

    social
  end

  def extract_logo_url(scraped_data)
    # This is a placeholder - logo extraction would require more complex logic
    nil
  end
end

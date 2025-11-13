class OrganizationsController < ApplicationController
  def index
    # Landing page with form to input URL
    # Shows organization type selector (company/school)

    # Handle auto-generate from user profile links
    if params[:auto_generate] == 'true' && params[:name].present?
      # Auto-generate organization profile from name
      # Default to company type, could be enhanced to detect school vs company
      organization_type = params[:organization_type] || 'company'
      company_name = params[:name]

      # Try to find the actual website URL using web search
      url = search_organization_website(company_name)

      # If we couldn't find a working URL, use best-guess generation
      if url.blank?
        url = generate_website_url_from_name(company_name)
        Rails.logger.warn "Could not verify URL for #{company_name}, using generated URL: #{url}"
      end

      begin
        # Generate unique cache key for this job
        cache_key = "organization_processing_#{SecureRandom.hex(16)}"

        # Store initial status in cache
        Rails.cache.write("#{cache_key}_status", 'processing', expires_in: 1.hour)

        # Store cache key and metadata in session
        session[:profile_cache_key] = cache_key
        session[:organization_type] = organization_type
        session[:organization_name] = company_name
        session[:organization_url] = url

        # Enqueue background job with website URL and organization type
        OrganizationProcessingJob.perform_later(url, organization_type, cache_key)

        # Redirect to result page which will poll for completion
        redirect_to organizations_result_path
      rescue => e
        Rails.logger.error "Failed to auto-generate organization profile: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        flash[:alert] = "Could not auto-generate profile for #{company_name}. Please try again or enter the website URL manually."
        redirect_to organizations_path
      end
    end
  end

  def process_url
    url = params[:url]
    organization_type = params[:organization_type] # 'company' or 'school'

    # Validate URL parameter
    if url.blank?
      redirect_to organizations_path, alert: 'Please provide a valid URL'
      return
    end

    # Validate organization_type parameter
    if organization_type.blank? || !['company', 'school'].include?(organization_type)
      redirect_to organizations_path, alert: 'Please select an organization type'
      return
    end

    begin
      # Generate unique cache key for this job
      cache_key = "organization_processing_#{SecureRandom.hex(16)}"

      # Store initial status in cache
      Rails.cache.write("#{cache_key}_status", 'processing', expires_in: 1.hour)

      # Store cache key in session to track this job
      session[:profile_cache_key] = cache_key
      session[:organization_type] = organization_type

      # Enqueue background job with website URL and organization type
      OrganizationProcessingJob.perform_later(url, organization_type, cache_key)

      # Redirect to result page which will poll for completion
      redirect_to organizations_result_path
    rescue => e
      Rails.logger.error "Failed to enqueue organization processing job: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to organizations_path, alert: "Error starting profile generation: #{e.message}"
    end
  end

  def result
    cache_key = session[:profile_cache_key]

    unless cache_key
      redirect_to organizations_path, alert: 'No processing job found. Please submit a URL first.'
      return
    end

    # Check job status from cache
    status = Rails.cache.read("#{cache_key}_status")

    case status
    when 'processing'
      # Still processing - show loading page with auto-refresh polling
      @processing = true
      @organization_type = session[:organization_type] || 'company'

    when 'completed'
      # Job completed - load partner from database
      partner_id = Rails.cache.read("#{cache_key}_partner_id")

      if partner_id
        # Load partner with all associations
        @partner = Partner.includes(
          :company_detail,
          :departments,
          :topics,
          :industries,
          :pdtopics,
          :domain_experts,
          :skills
        ).find_by(id: partner_id)

        if @partner
          @organization_type = @partner.category
          @processing = false

          # Get comprehensive details from cache
          cached_data = Rails.cache.read("#{cache_key}_data") || {}
          comprehensive_details = cached_data[:comprehensive_details] || {}

          # Build @profile_data hash for the view
          @profile_data = build_organization_profile_data(@partner, comprehensive_details)
        else
          redirect_to organizations_path, alert: 'Partner record not found.'
        end
      else
        redirect_to organizations_path, alert: 'No partner ID found in cache.'
      end

    when 'failed'
      # Job failed - show error message
      error_message = Rails.cache.read("#{cache_key}_error") || 'Unknown error occurred'
      redirect_to organizations_path, alert: "Profile generation failed: #{error_message}"

    else
      # No status found - job may have expired
      redirect_to organizations_path, alert: 'Processing session expired. Please try again.'
    end
  end

  def update_profile
    partner_id = params[:id]

    unless partner_id
      redirect_to organizations_path, alert: 'Partner ID is required.'
      return
    end

    @partner = Partner.find_by(id: partner_id)

    unless @partner
      redirect_to organizations_path, alert: 'Partner not found.'
      return
    end

    begin
      # Update partner with nested attributes
      if @partner.update(partner_params)
        # Handle logo upload via ActiveStorage
        if params[:partner][:logo_image].present?
          @partner.logo.purge if @partner.logo.attached?
          @partner.logo.attach(params[:partner][:logo_image])
        end

        # Handle banner upload via ActiveStorage
        if params[:partner][:banner_image].present?
          @partner.banner.purge if @partner.banner.attached?
          @partner.banner.attach(params[:partner][:banner_image])
        end

        # Handle promo video upload via ActiveStorage
        if params[:partner][:promo_video].present?
          @partner.promo_video.purge if @partner.promo_video.attached?
          @partner.promo_video.attach(params[:partner][:promo_video])
        end

        # Handle tag associations
        update_tag_associations(@partner)

        redirect_to organizations_result_path, notice: 'Profile updated successfully!'
      else
        redirect_to organizations_result_path, alert: "Failed to update profile: #{@partner.errors.full_messages.join(', ')}"
      end
    rescue => e
      Rails.logger.error "Profile update error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to organizations_result_path, alert: "Error updating profile: #{e.message}"
    end
  end

  private

  # Search for organization's actual website URL using web search
  # Returns the URL if found, nil otherwise
  def search_organization_website(organization_name)
    begin
      Rails.logger.info "Searching for website URL for: #{organization_name}"

      # Try common domain patterns first
      potential_urls = generate_potential_urls(organization_name)

      # Check each potential URL to see if it resolves
      potential_urls.each do |url|
        if url_exists?(url)
          Rails.logger.info "Found working URL: #{url}"
          return url
        end
      end

      Rails.logger.warn "Could not find working URL for: #{organization_name}"
      nil
    rescue => e
      Rails.logger.error "Error searching for organization website: #{e.message}"
      nil
    end
  end

  # Generate potential URLs based on organization name
  def generate_potential_urls(name)
    urls = []

    # Get the base slug using our smart generation
    base_slug = generate_website_url_from_name(name).gsub('https://www.', '').gsub('.com', '')

    # Try common TLD variations
    urls << "https://www.#{base_slug}.com"
    urls << "https://www.#{base_slug}.org"
    urls << "https://#{base_slug}.com"
    urls << "https://#{base_slug}.org"

    # Try with acronym if name has multiple words
    words = name.split(/\s+/).reject { |w| w.length < 2 }
    if words.length >= 2
      acronym = words.map { |w| w[0] }.join('').downcase
      urls << "https://www.#{acronym}.com"
      urls << "https://www.#{acronym}.org"
    end

    # Try the full name as one word
    full_name_slug = name.downcase.gsub(/[^a-z0-9]/, '')
    if full_name_slug != base_slug
      urls << "https://www.#{full_name_slug}.com"
      urls << "https://www.#{full_name_slug}.org"
    end

    urls.uniq
  end

  # Check if a URL exists and is accessible
  def url_exists?(url)
    begin
      response = HTTParty.head(url,
        timeout: 5,
        follow_redirects: true,
        headers: {
          'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
      )
      response.success?
    rescue => e
      Rails.logger.debug "URL check failed for #{url}: #{e.message}"
      false
    end
  end

  # Generate a website URL from organization name by extracting significant words
  # Removes common filler words and uses only first 2-3 significant words
  def generate_website_url_from_name(name)
    # Common filler words to remove (case-insensitive)
    filler_words = %w[
      society association organization institute foundation
      of the and for in at to a an
      international national global local regional
      american united states us uk
    ]

    # Split name into words, remove special characters, convert to lowercase
    words = name.downcase
                .gsub(/[^a-z0-9\s]/, ' ')  # Replace special chars with spaces
                .split(/\s+/)               # Split on whitespace
                .reject { |word| filler_words.include?(word) }  # Remove filler words
                .reject { |word| word.length < 2 }  # Remove single letter words

    # If no significant words remain, fall back to first 3 words of original name
    if words.empty?
      words = name.downcase
                  .gsub(/[^a-z0-9\s]/, '')
                  .split(/\s+/)
                  .first(3)
    end

    # Take first 2-3 significant words (prefer 2 for shorter domains)
    significant_words = if words.length <= 2
                          words
                        elsif words.first.length >= 6  # If first word is long, use only 2 words
                          words.first(2)
                        else
                          words.first(3)  # Otherwise use 3 words
                        end

    # Create URL slug from significant words
    url_slug = significant_words.join('-')

    # Build final URL
    "https://www.#{url_slug}.com"
  end

  # Build profile data hash from Partner model for view rendering
  def build_organization_profile_data(partner, comprehensive_details = {})
    {
      "name" => partner.name || "Organization Name",
      "website" => partner.website || "",
      "logoUrl" => partner.logo.attached? ? url_for(partner.logo) : nil,
      "bannerUrl" => partner.banner.attached? ? url_for(partner.banner) : nil,
      "promoVideoUrl" => partner.promo_video.attached? ? url_for(partner.promo_video) : nil,
      "shortDescription" => partner.short_description.to_s.presence || "No description available",
      "longDescription" => partner.long_description.to_s.presence || "",
      "description" => partner.long_description.to_s.presence || partner.overview.to_s.presence || "No description available",
      "overview" => partner.overview.to_s.presence || "",
      "tagline" => partner.tagline.to_s.presence || "",
      "yearFounded" => partner.year_founded,
      "address" => partner.address || "",
      "country" => partner.country || "",
      "category" => partner.category || "company",
      "organizationType" => partner.organization_type || "",
      "employeesCount" => partner.employees_count || "",
      "studentsCount" => partner.students_count,
      "socialMedia" => {
        "facebook" => partner.facebook,
        "linkedin" => partner.linkedin,
        "twitter" => partner.twitter,
        "youtube" => partner.youtube,
        "instagram" => partner.instagram
      },
      "videoUrl" => partner.video_url,
      "businessModel" => partner.business_model,
      "companyDetail" => partner.company_detail ? {
        "headquarter" => partner.company_detail.headquarter,
        "growthStage" => partner.company_detail.growth_stage,
        "employeeSize" => partner.company_detail.employee_size,
        "globalStatus" => partner.company_detail.global_status,
        "experientialLearningExperience" => partner.company_detail.experiential_learning_experience,
        "remoteCollaborationPreferences" => partner.company_detail.remote_collaboration_preferences,
        "studentSeniorityPreferences" => partner.company_detail.student_seniority_preferences,
        "sponsor" => partner.company_detail.sponsor
      } : {},
      "departments" => partner.departments.map { |d| { "name" => d.name } },
      "topics" => partner.topics.pluck(:name),
      "industries" => partner.industries.pluck(:name),
      "pdtopics" => partner.pdtopics.pluck(:name),
      "domainExperts" => partner.domain_experts.pluck(:name),
      "skills" => partner.skills.pluck(:name),
      # Flatten comprehensive details to top level for view compatibility
      "similarOrganizations" => comprehensive_details[:similar_organizations] || [],
      "studentInfo" => comprehensive_details[:student_info] || ""
    }
  end

  def partner_params
    permitted_params = params.require(:partner).permit(
      :name,
      :website,
      :address,
      :year_founded,
      :country,
      :category,
      :organization_type,
      :employees_count,
      :students_count,
      :facebook,
      :linkedin,
      :twitter,
      :youtube,
      :instagram,
      :video_url,
      :business_model,
      :primary_color,
      :menu_color,
      :anchor_color,
      :short_description,
      :long_description,
      :overview,
      :tagline,
      company_detail_attributes: [
        :id,
        :headquarter,
        :growth_stage,
        :employee_size,
        :global_status,
        :experiential_learning_experience,
        :remote_collaboration_preferences,
        :student_seniority_preferences,
        :sponsor
      ],
      departments_attributes: [
        :id,
        :name,
        :_destroy
      ]
    )

    # Handle rich text fields
    if params[:partner][:short_description].present?
      permitted_params[:short_description] = params[:partner][:short_description]
    end

    if params[:partner][:long_description].present?
      permitted_params[:long_description] = params[:partner][:long_description]
    end

    # Map "description" form field to "long_description" database field
    if params[:partner][:description].present?
      permitted_params[:long_description] = params[:partner][:description]
    end

    if params[:partner][:overview].present?
      permitted_params[:overview] = params[:partner][:overview]
    end

    if params[:partner][:tagline].present?
      permitted_params[:tagline] = params[:partner][:tagline]
    end

    permitted_params
  end

  def update_tag_associations(partner)
    # Update topics
    if params[:partner][:topic_ids].present?
      topic_ids = params[:partner][:topic_ids].reject(&:blank?).map(&:to_i)
      partner.topics = Tag.where(id: topic_ids, category: :topics)
    end

    # Update industries
    if params[:partner][:industry_ids].present?
      industry_ids = params[:partner][:industry_ids].reject(&:blank?).map(&:to_i)
      partner.industries = Tag.where(id: industry_ids, category: :industries)
    end

    # Update pdtopics
    if params[:partner][:pdtopic_ids].present?
      pdtopic_ids = params[:partner][:pdtopic_ids].reject(&:blank?).map(&:to_i)
      partner.pdtopics = Tag.where(id: pdtopic_ids, category: :pdtopics)
    end

    # Update domain experts
    if params[:partner][:domain_expert_ids].present?
      domain_expert_ids = params[:partner][:domain_expert_ids].reject(&:blank?).map(&:to_i)
      partner.domain_experts = Tag.where(id: domain_expert_ids, category: :domain_experts)
    end

    # Update skills
    if params[:partner][:skill_ids].present?
      skill_ids = params[:partner][:skill_ids].reject(&:blank?).map(&:to_i)
      partner.skills = Tag.where(id: skill_ids, category: :skills)
    end

    # Handle tag name arrays (create tags if they don't exist)
    if params[:partner][:topic_names].present?
      topic_names = params[:partner][:topic_names].is_a?(String) ?
        params[:partner][:topic_names].split(',').map(&:strip) :
        params[:partner][:topic_names]

      topics = topic_names.map { |name| Tag.find_or_create_topic(name) }
      partner.topics << topics
      partner.topics.uniq!
    end

    if params[:partner][:industry_names].present?
      industry_names = params[:partner][:industry_names].is_a?(String) ?
        params[:partner][:industry_names].split(',').map(&:strip) :
        params[:partner][:industry_names]

      industries = industry_names.map { |name| Tag.find_or_create_industry(name) }
      partner.industries << industries
      partner.industries.uniq!
    end

    if params[:partner][:skill_names].present?
      skill_names = params[:partner][:skill_names].is_a?(String) ?
        params[:partner][:skill_names].split(',').map(&:strip) :
        params[:partner][:skill_names]

      skills = skill_names.map { |name| Tag.find_or_create_skill(name) }
      partner.skills << skills
      partner.skills.uniq!
    end

    # Update hiring potentials for company_detail
    if partner.company_detail && params[:partner][:hiring_potential_ids].present?
      hiring_potential_ids = params[:partner][:hiring_potential_ids].reject(&:blank?).map(&:to_i)
      partner.company_detail.hiring_potentials = Tag.where(id: hiring_potential_ids, category: :hiring_potentials)
    end
  end
end

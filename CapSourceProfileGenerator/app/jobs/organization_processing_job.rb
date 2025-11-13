class OrganizationProcessingJob < ApplicationJob
  queue_as :default

  # Retry on errors with exponential backoff
  retry_on StandardError, wait: 30.seconds, attempts: 3

  # This job handles the organization scraping and AI enhancement asynchronously
  # so the main application doesn't slow down while processing organization data
  def perform(website_url, organization_type, cache_key)
    Rails.logger.info "Starting organization processing job for cache key: #{cache_key}"
    Rails.logger.info "Website URL: #{website_url}, Organization Type: #{organization_type}"

    begin
      # Mark processing as started
      Rails.cache.write("#{cache_key}_status", 'processing', expires_in: 1.hour)

      # Step 1: Scrape the website
      Rails.logger.info "Step 1: Scraping website #{website_url}"
      scraper = OrganizationScraper.new(website_url)
      scraped_data = scraper.scrape

      # Step 2: Enhance with OpenAI
      Rails.logger.info "Step 2: Enhancing organization data with OpenAI"
      enhancer = OpenaiOrganizationEnhancer.new

      enhanced_data = if organization_type == 'company'
                        enhancer.enhance_company_profile(scraped_data, website_url)
                      else
                        enhancer.enhance_university_profile(scraped_data, website_url)
                      end

      # Step 3: Create Partner record with enhanced data
      Rails.logger.info "Step 3: Creating Partner record"
      partner = create_partner(enhanced_data)

      # Step 4: Set ActionText fields
      Rails.logger.info "Step 4: Setting ActionText fields"
      set_action_text_fields(partner, enhanced_data)

      # Step 5: Create CompanyDetail if category is 'company'
      if partner.company?
        Rails.logger.info "Step 5: Creating CompanyDetail record"
        create_company_detail(partner, enhanced_data)
      else
        Rails.logger.info "Step 5: Skipping CompanyDetail (organization is a school)"
      end

      # Step 6: Create Department records
      Rails.logger.info "Step 6: Creating Department records"
      create_departments(partner, enhanced_data)

      # Step 7: Create/find tags and associate to partner
      Rails.logger.info "Step 7: Creating and associating tags"
      create_tag_associations(partner, enhanced_data)

      # Step 8: Mark processing as complete with partner_id and comprehensive details
      Rails.cache.write("#{cache_key}_status", 'completed', expires_in: 1.hour)
      Rails.cache.write("#{cache_key}_partner_id", partner.id, expires_in: 1.hour)
      Rails.cache.write("#{cache_key}_data", {
        partner_id: partner.id,
        partner_name: partner.name,
        partner_category: partner.category,
        comprehensive_details: enhanced_data[:comprehensive_details] || {}
      }, expires_in: 1.hour)

      Rails.logger.info "Organization processing completed successfully. Partner ID: #{partner.id}"

    rescue => e
      Rails.logger.error "Organization processing failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Mark processing as failed and store error message
      Rails.cache.write("#{cache_key}_status", 'failed', expires_in: 1.hour)
      Rails.cache.write("#{cache_key}_error", e.message, expires_in: 1.hour)

      # Re-raise the error so the job is marked as failed and can retry
      raise
    end
  end

  private

  def create_partner(enhanced_data)
    partner_data = enhanced_data[:partner]

    # Map organization type string to enum
    org_type = partner_data[:organization_type]
    if org_type.present?
      # Convert string to symbol for enum lookup
      org_type = org_type.to_sym if org_type.is_a?(String)
    end

    # Map employees count string to enum
    employees_count = partner_data[:employees_count]
    if employees_count.present?
      employees_count = employees_count.to_sym if employees_count.is_a?(String)
    end

    # Create partner without rich text fields (will be set separately)
    Partner.create!(
      name: partner_data[:name],
      website: partner_data[:website],
      address: partner_data[:address],
      year_founded: partner_data[:year_founded],
      category: partner_data[:category],
      organization_type: org_type,
      employees_count: employees_count,
      linkedin: partner_data[:linkedin],
      facebook: partner_data[:facebook],
      twitter: partner_data[:twitter],
      youtube: partner_data[:youtube],
      instagram: partner_data[:instagram],
      business_model: partner_data[:business_model]
    )
  end

  def set_action_text_fields(partner, enhanced_data)
    partner_data = enhanced_data[:partner]

    # Set rich text fields using update method
    # The HTML content is already formatted by the enhancer
    partner.update!(
      short_description: partner_data[:short_description],
      long_description: partner_data[:long_description],
      tagline: partner_data[:tagline],
      overview: partner_data[:overview]
    )
  end

  def create_company_detail(partner, enhanced_data)
    company_detail_data = enhanced_data[:company_detail] || {}

    # Map growth stage string to enum
    growth_stage = company_detail_data[:growth_stage]
    if growth_stage.present?
      growth_stage = growth_stage.to_sym if growth_stage.is_a?(String)
    end

    # Create or update company detail
    if partner.company_detail.present?
      partner.company_detail.update!(
        headquarter: company_detail_data[:headquarter],
        growth_stage: growth_stage,
        administrators: company_detail_data[:administrators]
      )
    else
      CompanyDetail.create!(
        partner: partner,
        headquarter: company_detail_data[:headquarter],
        growth_stage: growth_stage,
        administrators: company_detail_data[:administrators]
      )
    end
  end

  def create_departments(partner, enhanced_data)
    departments_data = enhanced_data[:departments] || []

    departments_data.each do |dept_name|
      next if dept_name.blank?

      Department.create!(
        partner: partner,
        name: dept_name.strip
      )
    end
  rescue => e
    Rails.logger.warn "Failed to create some departments: #{e.message}"
    # Don't fail the entire job if department creation fails
  end

  def create_tag_associations(partner, enhanced_data)
    tags_data = enhanced_data[:tags] || {}

    # Development interests -> pdtopics category
    development_interests = tags_data[:development_interests] || []
    development_interests.each do |interest_name|
      next if interest_name.blank?

      tag = Tag.find_or_create_pdtopic(interest_name)
      TagResource.find_or_create_by!(tag: tag, resource: partner)
    end

    # Areas of expertise -> domain_experts category
    areas_of_expertise = tags_data[:areas_of_expertise] || []
    areas_of_expertise.each do |expertise_name|
      next if expertise_name.blank?

      tag = Tag.find_or_create_domain_expert(expertise_name)
      TagResource.find_or_create_by!(tag: tag, resource: partner)
    end

    # Skills -> skills category
    skills = tags_data[:skills] || []
    skills.each do |skill_name|
      next if skill_name.blank?

      tag = Tag.find_or_create_skill(skill_name)
      TagResource.find_or_create_by!(tag: tag, resource: partner)
    end

    Rails.logger.info "Created tag associations: #{development_interests.size} pdtopics, #{areas_of_expertise.size} domain_experts, #{skills.size} skills"
  rescue => e
    Rails.logger.warn "Failed to create some tag associations: #{e.message}"
    # Don't fail the entire job if tag creation fails
  end
end

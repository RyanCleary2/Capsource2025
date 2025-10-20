class OrganizationsController < ApplicationController
  def index
    # Landing page with form to input URL
  end

  def process_url
    url = params[:url]
    organization_type = params[:organization_type] # 'company' or 'school'

    if url.blank?
      redirect_to root_path, alert: 'Please provide a valid URL'
      return
    end

    if organization_type.blank? || !['company', 'school'].include?(organization_type)
      redirect_to root_path, alert: 'Please select an organization type'
      return
    end

    begin
      # Scrape the website
      scraper = OrganizationScraper.new(url)
      scraped_data = scraper.scrape

      # Enhance with AI
      enhancer = OpenaiOrganizationEnhancer.new

      profile_data = if organization_type == 'company'
        enhancer.enhance_company_profile(scraped_data, url)
      else
        enhancer.enhance_university_profile(scraped_data, url)
      end

      # Add organization type to profile data
      profile_data['category'] = organization_type

      # Store in cache
      cache_key = "profile_data_#{SecureRandom.hex(16)}"
      Rails.cache.write(cache_key, profile_data, expires_in: 1.hour)
      session[:profile_cache_key] = cache_key
      session[:organization_type] = organization_type

      redirect_to result_path
    rescue => e
      Rails.logger.error "Profile generation error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to root_path, alert: "Error generating profile: #{e.message}"
    end
  end

  def result
    cache_key = session[:profile_cache_key]
    @profile_data = Rails.cache.read(cache_key) if cache_key
    @organization_type = session[:organization_type] || 'company'

    if @profile_data.nil?
      redirect_to root_path, alert: 'No data found. Please submit a URL first.'
    end
  end

  def update_profile
    cache_key = session[:profile_cache_key]
    profile_data = Rails.cache.read(cache_key) if cache_key
    organization_type = session[:organization_type] || 'company'

    if profile_data
      # Handle logo upload
      if params[:logo_image].present?
        uploaded_file = params[:logo_image]
        if uploaded_file.content_type.start_with?('image/')
          # Create uploads directory if it doesn't exist
          FileUtils.mkdir_p(Rails.root.join('public', 'uploads', 'logos'))

          filename = "#{SecureRandom.hex(16)}_#{uploaded_file.original_filename}"
          file_path = Rails.root.join('public', 'uploads', 'logos', filename)

          File.open(file_path, 'wb') do |file|
            file.write(uploaded_file.read)
          end

          profile_data["logoUrl"] = "/uploads/logos/#{filename}"
        end
      end

      # Handle banner upload
      if params[:banner_image].present?
        uploaded_file = params[:banner_image]
        if uploaded_file.content_type.start_with?('image/')
          FileUtils.mkdir_p(Rails.root.join('public', 'uploads', 'banners'))

          filename = "#{SecureRandom.hex(16)}_#{uploaded_file.original_filename}"
          file_path = Rails.root.join('public', 'uploads', 'banners', filename)

          File.open(file_path, 'wb') do |file|
            file.write(uploaded_file.read)
          end

          profile_data["bannerUrl"] = "/uploads/banners/#{filename}"
        end
      end

      # Update profile data with form values
      update_params = profile_params(organization_type).except(:logo_image, :banner_image)
      profile_data.merge!(update_params)

      Rails.cache.write(cache_key, profile_data, expires_in: 1.hour)
      redirect_to result_path, notice: 'Profile updated successfully!'
    else
      redirect_to root_path, alert: 'No data found. Please submit a URL first.'
    end
  end

  private

  def profile_params(org_type)
    if org_type == 'company'
      params.permit(
        :name, :description, :website, :yearFounded, :address,
        :numberOfEmployees, :businessModel, :organizationType, :tagline,
        :logo_image, :banner_image,
        socialMedia: [:linkedin, :facebook, :twitter, :instagram, :youtube]
      )
    else # school
      params.permit(
        :name, :description, :website, :yearFounded, :address,
        :numberOfStudents, :numberOfEmployees, :organizationType,
        :tagline, :administrators, :logo_image, :banner_image,
        socialMedia: [:linkedin, :facebook, :twitter, :instagram, :youtube]
      )
    end
  end
end

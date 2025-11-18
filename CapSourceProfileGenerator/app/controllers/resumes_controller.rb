class ResumesController < ApplicationController
  # Display the upload form
  def index
  end

  # Process uploaded resume and create user
  def process_resume
    if params[:file].present? && params[:file].content_type == 'application/pdf'
      begin
        # Create a new student user first
        user = Users::Student.create!(
          type: 'Users::Student',
          email: "student_#{SecureRandom.hex(8)}@temp.capsource.com"
        )

        # Store user_id in session for later retrieval
        session[:current_user_id] = user.id
        session[:profile_id] = user.profile.id

        # Generate cache key for job status tracking (must match the job's cache key)
        cache_key = "resume_processing_#{user.id}"
        session[:profile_cache_key] = cache_key

        # Save uploaded file to a persistent location for the background job
        uploads_dir = Rails.root.join('tmp', 'uploads')
        FileUtils.mkdir_p(uploads_dir) unless Dir.exist?(uploads_dir)

        file_path = uploads_dir.join("resume_#{user.id}_#{Time.current.to_i}.pdf")
        File.open(file_path, 'wb') do |file|
          file.write(params[:file].read)
        end

        # Mark processing as in progress
        Rails.cache.write("#{cache_key}_status", 'processing', expires_in: 1.hour)

        # Enqueue the background job to process the resume
        # Pass user_id instead of just cache_key
        ResumeProcessingJob.perform_later(file_path.to_s, user.id)

        redirect_to profiles_result_path, notice: 'Resume is being processed. Please wait...'
      rescue => e
        Rails.logger.error "Error enqueueing resume processing: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        redirect_to profiles_path, alert: 'Error processing PDF. Please try again or use a different file.'
      end
    else
      redirect_to profiles_path, alert: 'Please upload a valid PDF file'
    end
  end

  # Display processing status and profile data
  def result
    user_id = session[:current_user_id]
    profile_id = session[:profile_id]
    cache_key = session[:profile_cache_key]

    if user_id.nil? || profile_id.nil?
      redirect_to profiles_path, alert: 'No data found. Please upload a resume first.'
      return
    end

    # Check the processing status from cache
    @processing_status = Rails.cache.read("#{cache_key}_status")
    @error_message = Rails.cache.read("#{cache_key}_error")

    case @processing_status
    when 'processing'
      # Still processing - the view should show a loading state
      # and auto-refresh or use JavaScript to poll for completion
      flash.now[:notice] = 'Your resume is being processed. This may take a few moments...'
      @profile = nil
    when 'failed'
      # Processing failed
      flash.now[:alert] = "Processing failed: #{@error_message || 'Unknown error'}"
      @profile = nil
    when 'completed'
      # Processing completed - load profile from database with all associations
      @profile = Profile.includes(:educational_backgrounds, :professional_backgrounds, :skills)
                        .find_by(id: profile_id)

      if @profile.nil?
        redirect_to profiles_path, alert: 'Processing completed but profile not found. Please try again.'
        return
      end

      # Load the user for personal information
      @user = @profile.user

      # Build @profile_data hash for the view (matching the expected structure)
      @profile_data = build_profile_data_hash(@profile, @user)
    else
      # No status found
      redirect_to profiles_path, alert: 'No processing status found. Please upload a resume first.'
    end
  end

  # Update profile data from edit form
  def update_profile
    profile_id = session[:profile_id] || params[:profile_id]

    unless profile_id
      redirect_to profiles_path, alert: 'No profile found. Please upload a resume first.'
      return
    end

    @profile = Profile.includes(:educational_backgrounds, :professional_backgrounds).find_by(id: profile_id)

    unless @profile
      redirect_to profiles_path, alert: 'Profile not found. Please upload a resume first.'
      return
    end

    begin
      ActiveRecord::Base.transaction do
        # Update user personal information
        @profile.user.update!(user_params) if params[:user].present?

        # Update profile about/professional summary
        @profile.update!(profile_params)

        # Handle profile image upload via ActiveStorage
        if params[:profile_image].present?
          @profile.user.profile_image.attach(params[:profile_image])
        end

        # Update educational backgrounds
        if params[:educational_backgrounds_attributes].present?
          update_educational_backgrounds
        end

        # Update professional backgrounds
        if params[:professional_backgrounds_attributes].present?
          update_professional_backgrounds
        end
      end

      # Set cache status to 'completed' so the result page doesn't show loading screen
      cache_key = session[:profile_cache_key]
      if cache_key
        Rails.cache.write("#{cache_key}_status", 'completed', expires_in: 1.hour)
      end

      redirect_to profiles_result_path, notice: 'Profile updated successfully!'
    rescue => e
      Rails.logger.error "Error updating profile: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      flash[:alert] = "Error updating profile: #{e.message}"
      render :result
    end
  end

  private

  def build_profile_data_hash(profile, user)
    {
      "profileImageUrl" => user.avatar.attached? ? url_for(user.avatar) : nil,
      "personalInfo" => {
        "fullName" => "#{user.first_name} #{user.last_name}".strip.presence || "Name not found",
        "email" => user.email || "",
        "phone" => user.phone_number || "",
        "location" => user.location || "",
        "linkedin" => user.linkedin || "",
        "website" => user.website || ""
      },
      "professionalSummary" => profile.about.to_s.presence || "No summary available",
      "experience" => profile.professional_backgrounds.map do |pb|
        {
          "title" => pb.position || "",
          "company" => pb.employer || "",
          "location" => pb.location || "",
          "startDate" => "#{pb.start_month} #{pb.start_year}".strip,
          "endDate" => pb.current_job ? "Present" : "#{pb.end_month} #{pb.end_year}".strip,
          "description" => pb.description || "",
          "keyAchievements" => parse_achievements(pb.achievements)
        }
      end,
      "education" => profile.educational_backgrounds.map do |eb|
        {
          "degree" => eb.degree || "",
          "institution" => eb.university_college || "",
          "graduationYear" => eb.graduation_year,
          "gpa" => eb.gpa,
          "honors" => eb.honors
        }
      end,
      "skills" => {
        "technical" => profile.skills.limit(10).pluck(:name),
        "soft" => [],
        "languages" => []
      },
      "certifications" => [],
      "projects" => []
    }
  end

  def user_params
    params.require(:user).permit(
      :first_name,
      :last_name,
      :email,
      :phone_number,
      :location,
      :website,
      :linkedin
    )
  end

  def profile_params
    params.require(:profile).permit(:about)
  end

  def educational_background_params
    params.permit(
      educational_backgrounds_attributes: [
        :id,
        :university_college,
        :degree,
        :major,
        :graduation_year,
        :month_start,
        :month_end,
        :year_start,
        :year_end,
        :gpa,
        :honors,
        :_destroy
      ]
    )[:educational_backgrounds_attributes]
  end

  def professional_background_params
    params.permit(
      professional_backgrounds_attributes: [
        :id,
        :employer,
        :position,
        :location,
        :current_job,
        :start_month,
        :start_year,
        :end_month,
        :end_year,
        :description,
        :achievements,
        :_destroy
      ]
    )[:professional_backgrounds_attributes]
  end

  def update_educational_backgrounds
    educational_background_params.each do |id, attrs|
      if attrs[:_destroy] == '1'
        @profile.educational_backgrounds.find(id).destroy if id.present?
      elsif id.present?
        @profile.educational_backgrounds.find(id).update!(attrs.except(:_destroy))
      else
        @profile.educational_backgrounds.create!(attrs.except(:_destroy))
      end
    end
  end

  def update_professional_backgrounds
    professional_background_params.each do |id, attrs|
      if attrs[:_destroy] == '1'
        @profile.professional_backgrounds.find(id).destroy if id.present?
      elsif id.present?
        @profile.professional_backgrounds.find(id).update!(attrs.except(:_destroy))
      else
        @profile.professional_backgrounds.create!(attrs.except(:_destroy))
      end
    end
  end

  # Parse achievements from HTML or JSON format into an array
  # @param achievements [String] The achievements text (HTML or JSON)
  # @return [Array<String>] Array of achievement strings
  def parse_achievements(achievements)
    return [] if achievements.blank?

    # Check if it's HTML format (from format_text_as_bullet_points)
    if achievements.strip.start_with?('<ul>', '<ol>')
      # Parse HTML and extract list items
      doc = Nokogiri::HTML.fragment(achievements)
      doc.css('li').map { |li| li.text.strip }.reject(&:blank?)
    else
      # Try to parse as JSON (legacy format or direct array)
      begin
        JSON.parse(achievements)
      rescue JSON::ParserError
        # If it's plain text, return as single-item array
        [achievements.strip]
      end
    end
  end
end
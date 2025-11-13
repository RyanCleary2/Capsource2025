class ResumeProcessingJob < ApplicationJob
  queue_as :default

  # This job handles the PDF parsing, AI enhancement, and database persistence asynchronously
  # so the main application doesn't slow down or stop working while processing
  #
  # @param file_path [String] Path to the uploaded PDF resume file
  # @param user_id [Integer] ID of the user for whom the profile is being created
  def perform(file_path, user_id)
    cache_key = "resume_processing_#{user_id}"

    Rails.logger.info "Starting resume processing job for user ID: #{user_id}"
    Rails.logger.info "Processing file: #{file_path}"

    begin
      # Set cache status to 'processing'
      Rails.cache.write("#{cache_key}_status", 'processing', expires_in: 1.hour)

      # Parse the PDF resume
      parser = ResumeParser.new(file_path)
      profile_data = parser.parse_profile_data

      Rails.logger.info "Resume parsed successfully for user ID: #{user_id}"
      Rails.logger.info "Parsed user data: #{profile_data[:user].inspect}"
      Rails.logger.info "Parsed education data: #{profile_data[:educational_backgrounds].inspect}"
      Rails.logger.info "Parsed professional data: #{profile_data[:professional_backgrounds].inspect}"

      # Find the user
      user = User.find(user_id)
      Rails.logger.info "Found user: #{user.email || user.id}"

      # Find or create profile for the user
      profile = find_or_create_profile(user)
      Rails.logger.info "Profile found/created with ID: #{profile.id}"

      # Update profile with parsed data
      update_profile_with_data(profile, profile_data)
      Rails.logger.info "Profile updated with basic data"

      # Create educational backgrounds
      create_educational_backgrounds(profile, profile_data[:educational_backgrounds])
      Rails.logger.info "Educational backgrounds created: #{profile_data[:educational_backgrounds]&.length || 0} records"

      # Create professional backgrounds
      create_professional_backgrounds(profile, profile_data[:professional_backgrounds])
      Rails.logger.info "Professional backgrounds created: #{profile_data[:professional_backgrounds]&.length || 0} records"

      # Create and associate skill tags
      create_skill_tags(profile, profile_data[:skills])
      Rails.logger.info "Skill tags created and associated"

      # Mark processing as complete
      Rails.cache.write("#{cache_key}_status", 'completed', expires_in: 1.hour)
      Rails.cache.write("#{cache_key}_profile_id", profile.id, expires_in: 1.hour)

      Rails.logger.info "Resume processing completed successfully for user ID: #{user_id}"

    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "User not found with ID #{user_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Mark processing as failed and store error message
      Rails.cache.write("#{cache_key}_status", 'failed', expires_in: 1.hour)
      Rails.cache.write("#{cache_key}_error", "User not found. Please try again.", expires_in: 1.hour)

      # Re-raise the error so the job is marked as failed in the queue
      raise

    rescue => e
      Rails.logger.error "Resume processing failed for user ID #{user_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Mark processing as failed and store error message
      Rails.cache.write("#{cache_key}_status", 'failed', expires_in: 1.hour)
      Rails.cache.write("#{cache_key}_error", e.message, expires_in: 1.hour)

      # Re-raise the error so the job is marked as failed in the queue
      raise

    ensure
      # Clean up the temporary file
      if File.exist?(file_path)
        File.delete(file_path)
        Rails.logger.info "Temporary file deleted: #{file_path}"
      end
    end
  end

  private

  # Find or create a profile for the user
  # @param user [User] The user for whom to find or create a profile
  # @return [Profile] The found or created profile
  def find_or_create_profile(user)
    profile = user.profile

    if profile.nil?
      profile = Profile.create!(user: user, status: :draft)
      Rails.logger.info "Created new profile for user ID: #{user.id}"
    else
      Rails.logger.info "Using existing profile ID: #{profile.id}"
    end

    profile
  end

  # Update profile with parsed data from resume
  # @param profile [Profile] The profile to update
  # @param profile_data [Hash] The parsed profile data
  def update_profile_with_data(profile, profile_data)
    # Update User model with personal information
    if profile_data[:user].present?
      user_data = profile_data[:user]

      # Check if email already exists (and it's not the current user's email)
      new_email = user_data[:email]
      email_to_use = profile.user.email # Default to keeping current email

      if new_email.present? && new_email != profile.user.email
        # Check if this email is already taken by another user
        existing_user = User.where(email: new_email).where.not(id: profile.user.id).first

        if existing_user.nil?
          # Email is available, use it
          email_to_use = new_email
          Rails.logger.info "Updating email to: #{new_email}"
        else
          # Email exists on a different user - likely from a previous test upload
          # Delete the old user and their profile to avoid conflicts
          Rails.logger.warn "Email #{new_email} already exists on user ID #{existing_user.id}. Cleaning up old test data..."
          begin
            existing_user.profile&.destroy
            existing_user.destroy
            Rails.logger.info "Deleted old user #{existing_user.id} with duplicate email"
            email_to_use = new_email
          rescue => e
            Rails.logger.error "Failed to delete old user: #{e.message}"
            Rails.logger.warn "Keeping temporary email: #{profile.user.email}"
          end
        end
      end

      profile.user.update!(
        first_name: user_data[:first_name],
        last_name: user_data[:last_name],
        email: email_to_use,
        phone_number: user_data[:phone_number],
        location: user_data[:location],
        linkedin: user_data[:linkedin],
        website: user_data[:website]
      )
      Rails.logger.info "Updated user personal information: #{user_data[:first_name]} #{user_data[:last_name]}"
    end

    # Update profile.about with professional summary using ActionText
    if profile_data[:profile][:about].present?
      # ActionText requires HTML content
      about_html = "<p>#{ActionController::Base.helpers.sanitize(profile_data[:profile][:about])}</p>"
      profile.about = about_html
      Rails.logger.info "Updated profile.about with professional summary"
    end

    # Set profile status to draft
    profile.status = :draft

    # Save the profile
    profile.save!
    Rails.logger.info "Profile saved successfully"
  end

  # Create educational background records from parsed data
  # @param profile [Profile] The profile to associate educational backgrounds with
  # @param educational_data [Array<Hash>] Array of educational background data
  def create_educational_backgrounds(profile, educational_data)
    return if educational_data.blank?

    # Clear existing educational backgrounds to avoid duplicates
    profile.educational_backgrounds.destroy_all

    educational_data.each do |edu_data|
      # Skip if no meaningful data
      next if edu_data[:university_college].blank? && edu_data[:degree].blank?

      educational_background = profile.educational_backgrounds.create!(
        university_college: edu_data[:university_college],
        degree: edu_data[:degree],
        major: edu_data[:major],
        graduation_year: edu_data[:graduation_year],
        gpa: edu_data[:gpa],
        honors: edu_data[:honors]
      )

      Rails.logger.info "Created educational background: #{educational_background.university_college}"
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create educational background: #{e.message}"
      # Continue with other records even if one fails
    end
  end

  # Create professional background records from parsed data
  # @param profile [Profile] The profile to associate professional backgrounds with
  # @param professional_data [Array<Hash>] Array of professional background data
  def create_professional_backgrounds(profile, professional_data)
    return if professional_data.blank?

    # Clear existing professional backgrounds to avoid duplicates
    profile.professional_backgrounds.destroy_all

    professional_data.each do |job_data|
      # Skip if no meaningful data
      next if job_data[:employer].blank? && job_data[:position].blank?

      professional_background = profile.professional_backgrounds.create!(
        employer: job_data[:employer],
        position: job_data[:position],
        location: job_data[:location],
        start_month: job_data[:start_month],
        start_year: job_data[:start_year],
        end_month: job_data[:end_month],
        end_year: job_data[:end_year],
        current_job: job_data[:current_job] || false,
        description: job_data[:description],
        achievements: job_data[:achievements]
      )

      Rails.logger.info "Created professional background: #{professional_background.position} at #{professional_background.employer}"
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create professional background: #{e.message}"
      # Continue with other records even if one fails
    end
  end

  # Create skill tags and associate them with the profile via TagResource
  # @param profile [Profile] The profile to associate skills with
  # @param skills_data [Hash] Hash containing technical, soft, and language skills
  def create_skill_tags(profile, skills_data)
    return if skills_data.blank?

    # Clear existing skill tag associations to avoid duplicates
    profile.tag_resources.joins(:tag).where(tags: { category: Tag.categories[:skills] }).destroy_all

    # Process technical skills
    if skills_data[:technical].present?
      skills_data[:technical].each do |skill_name|
        next if skill_name.blank?

        begin
          # Find or create skill tag
          skill_tag = Tag.find_or_create_skill(skill_name)

          # Create tag resource association (with uniqueness validation)
          TagResource.find_or_create_by!(
            tag: skill_tag,
            resource: profile
          )

          Rails.logger.info "Associated skill tag: #{skill_name}"
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.warn "Skipping duplicate skill tag: #{skill_name}"
          # Continue with other skills even if one fails
        rescue => e
          Rails.logger.error "Failed to create skill tag '#{skill_name}': #{e.message}"
          # Continue with other skills even if one fails
        end
      end
    end

    # Process soft skills
    if skills_data[:soft].present?
      skills_data[:soft].each do |skill_name|
        next if skill_name.blank?

        begin
          # Find or create skill tag
          skill_tag = Tag.find_or_create_skill(skill_name)

          # Create tag resource association
          TagResource.find_or_create_by!(
            tag: skill_tag,
            resource: profile
          )

          Rails.logger.info "Associated soft skill tag: #{skill_name}"
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.warn "Skipping duplicate soft skill tag: #{skill_name}"
        rescue => e
          Rails.logger.error "Failed to create soft skill tag '#{skill_name}': #{e.message}"
        end
      end
    end

    # Process language skills
    if skills_data[:languages].present?
      skills_data[:languages].each do |skill_name|
        next if skill_name.blank?

        begin
          # Find or create skill tag
          skill_tag = Tag.find_or_create_skill(skill_name)

          # Create tag resource association
          TagResource.find_or_create_by!(
            tag: skill_tag,
            resource: profile
          )

          Rails.logger.info "Associated language skill tag: #{skill_name}"
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.warn "Skipping duplicate language skill tag: #{skill_name}"
        rescue => e
          Rails.logger.error "Failed to create language skill tag '#{skill_name}': #{e.message}"
        end
      end
    end
  end
end

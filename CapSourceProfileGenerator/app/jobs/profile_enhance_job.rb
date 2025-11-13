# frozen_string_literal: true

# ProfileEnhanceJob - Enhances profile data using OpenAI
#
# This job processes a profile through the OpenAI Profile Enhancer service
# to improve the quality and professionalism of profile data including:
# - Professional summary/about section
# - Educational backgrounds with enhanced descriptions
# - Professional backgrounds with improved achievements
# - Skills categorization and tagging
#
# Usage:
#   ProfileEnhanceJob.perform_later(profile_id)
#
# The job tracks its status in Rails cache using the key:
#   profile_enhance_status_#{profile_id}
#
# Status values: 'enhancing', 'completed', 'failed'
class ProfileEnhanceJob < ApplicationJob
  queue_as :default

  # Retry configuration for transient failures
  retry_on StandardError, wait: 30.seconds, attempts: 3

  MAX_RETRIES = 3
  RETRY_WAIT_SECONDS = 15
  CACHE_EXPIRATION = 10.minutes

  def perform(profile_id)
    Rails.logger.info "Starting profile enhancement job for profile ID: #{profile_id}"

    # Set initial status
    set_cache_status(profile_id, 'enhancing')

    begin
      # Load profile with all associations
      profile = load_profile_with_associations(profile_id)

      unless profile
        Rails.logger.error "Profile not found with ID: #{profile_id}"
        set_cache_status(profile_id, 'failed')
        return
      end

      Rails.logger.info "Loaded profile for user: #{profile.user.email}"

      # Build data structure for enhancer
      profile_data = build_profile_data(profile)
      Rails.logger.info "Built profile data structure for enhancement"

      # Call OpenAI enhancer with retry logic
      enhanced_data = enhance_profile_with_retry(profile_data)

      unless enhanced_data
        Rails.logger.error "Failed to enhance profile data after retries"
        set_cache_status(profile_id, 'failed')
        return
      end

      Rails.logger.info "Successfully enhanced profile data, starting database updates"

      # Update profile and related models in transaction
      ActiveRecord::Base.transaction do
        update_profile_about(profile, enhanced_data)
        update_educational_backgrounds(profile, enhanced_data)
        update_professional_backgrounds(profile, enhanced_data)
        create_skill_tags(profile, enhanced_data)
      end

      Rails.logger.info "Successfully updated all profile data"

      # Set success status
      set_cache_status(profile_id, 'completed')

      Rails.logger.info "Profile enhancement completed successfully for profile ID: #{profile_id}"

    rescue StandardError => e
      Rails.logger.error "Profile enhancement failed for profile ID #{profile_id}: #{e.class} - #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"

      # Set failed status
      set_cache_status(profile_id, 'failed')
      Rails.cache.write("profile_enhance_error_#{profile_id}", e.message, expires_in: CACHE_EXPIRATION)

      # Re-raise to mark job as failed
      raise
    end
  end

  private

  # Load profile with all necessary associations
  def load_profile_with_associations(profile_id)
    Profile.includes(
      :user,
      :educational_backgrounds,
      :professional_backgrounds,
      :skills
    ).find_by(id: profile_id)
  end

  # Build profile data structure for OpenAI enhancer
  def build_profile_data(profile)
    {
      user: {
        first_name: profile.user.first_name,
        last_name: profile.user.last_name,
        email: profile.user.email,
        phone_number: profile.user.phone_number,
        location: profile.user.location,
        linkedin: profile.user.linkedin,
        website: profile.user.website,
        type: profile.user.type
      },
      profile: {
        about: profile.about&.to_plain_text,
        status: profile.status
      },
      educational_backgrounds: profile.educational_backgrounds.map do |edu|
        {
          university_college: edu.university_college,
          degree: edu.degree,
          major: edu.major,
          graduation_year: edu.graduation_year,
          month_start: edu.month_start,
          month_end: edu.month_end,
          year_start: edu.year_start,
          year_end: edu.year_end,
          gpa: edu.gpa,
          honors: edu.honors
        }
      end,
      professional_backgrounds: profile.professional_backgrounds.map do |exp|
        {
          employer: exp.employer,
          position: exp.position,
          location: exp.location,
          start_month: exp.start_month,
          start_year: exp.start_year,
          end_month: exp.end_month,
          end_year: exp.end_year,
          current_job: exp.current_job,
          description: exp.description,
          achievements: exp.achievements
        }
      end,
      skills: {
        technical: profile.skills.pluck(:name),
        soft: [],
        languages: []
      }
    }
  end

  # Enhance profile data with retry logic
  def enhance_profile_with_retry(profile_data)
    retries = 0

    begin
      enhancer = OpenaiProfileEnhancer.new
      enhanced_data = enhancer.enhance_profile_data(profile_data)

      if enhanced_data.blank?
        Rails.logger.error 'OpenAI enhancer returned blank data'
        return nil
      end

      enhanced_data

    rescue StandardError => e
      Rails.logger.error "Enhancement attempt #{retries + 1} failed: #{e.class} - #{e.message}"

      if retries < MAX_RETRIES
        retries += 1
        Rails.logger.info "Retrying enhancement (attempt #{retries}/#{MAX_RETRIES}) after #{RETRY_WAIT_SECONDS} seconds..."
        sleep(RETRY_WAIT_SECONDS)
        retry
      end

      Rails.logger.error "Max retries (#{MAX_RETRIES}) exceeded for profile enhancement"
      nil
    end
  end

  # Update profile's about field with enhanced professional summary
  def update_profile_about(profile, enhanced_data)
    professional_summary = enhanced_data.dig(:profile, :about)

    if professional_summary.present?
      Rails.logger.info "Updating profile about field"
      profile.update!(about: professional_summary)
      Rails.logger.info "Profile about field updated successfully"
    else
      Rails.logger.warn "No professional summary in enhanced data"
    end
  end

  # Update educational backgrounds with enhanced data
  def update_educational_backgrounds(profile, enhanced_data)
    enhanced_education = enhanced_data[:educational_backgrounds]

    return unless enhanced_education&.any?

    Rails.logger.info "Updating #{enhanced_education.length} educational background(s)"

    enhanced_education.each_with_index do |edu_data, index|
      # Match by index or find closest match
      existing_edu = profile.educational_backgrounds[index]

      if existing_edu
        Rails.logger.info "Updating educational background: #{edu_data[:university_college]}"
        existing_edu.update!(
          university_college: edu_data[:university_college] || existing_edu.university_college,
          degree: edu_data[:degree] || existing_edu.degree,
          major: edu_data[:major] || existing_edu.major,
          graduation_year: edu_data[:graduation_year] || existing_edu.graduation_year,
          month_start: edu_data[:month_start] || existing_edu.month_start,
          month_end: edu_data[:month_end] || existing_edu.month_end,
          year_start: edu_data[:year_start] || existing_edu.year_start,
          year_end: edu_data[:year_end] || existing_edu.year_end,
          gpa: edu_data[:gpa] || existing_edu.gpa,
          honors: edu_data[:honors] || existing_edu.honors
        )
      else
        Rails.logger.info "Creating new educational background: #{edu_data[:university_college]}"
        profile.educational_backgrounds.create!(edu_data)
      end
    end

    Rails.logger.info "Educational backgrounds updated successfully"
  end

  # Update professional backgrounds with enhanced data
  def update_professional_backgrounds(profile, enhanced_data)
    enhanced_experience = enhanced_data[:professional_backgrounds]

    return unless enhanced_experience&.any?

    Rails.logger.info "Updating #{enhanced_experience.length} professional background(s)"

    enhanced_experience.each_with_index do |exp_data, index|
      # Match by index or find closest match
      existing_exp = profile.professional_backgrounds[index]

      if existing_exp
        Rails.logger.info "Updating professional background: #{exp_data[:position]} at #{exp_data[:employer]}"
        existing_exp.update!(
          employer: exp_data[:employer] || existing_exp.employer,
          position: exp_data[:position] || existing_exp.position,
          location: exp_data[:location] || existing_exp.location,
          start_month: exp_data[:start_month] || existing_exp.start_month,
          start_year: exp_data[:start_year] || existing_exp.start_year,
          end_month: exp_data[:end_month] || existing_exp.end_month,
          end_year: exp_data[:end_year] || existing_exp.end_year,
          current_job: exp_data.key?(:current_job) ? exp_data[:current_job] : existing_exp.current_job,
          description: exp_data[:description] || existing_exp.description,
          achievements: exp_data[:achievements] || existing_exp.achievements
        )
      else
        Rails.logger.info "Creating new professional background: #{exp_data[:position]} at #{exp_data[:employer]}"
        profile.professional_backgrounds.create!(exp_data)
      end
    end

    Rails.logger.info "Professional backgrounds updated successfully"
  end

  # Create tag associations for skills
  def create_skill_tags(profile, enhanced_data)
    skills_data = enhanced_data[:skills]

    return unless skills_data

    all_skills = []
    all_skills += skills_data[:technical] if skills_data[:technical]&.any?
    all_skills += skills_data[:soft] if skills_data[:soft]&.any?
    all_skills += skills_data[:languages] if skills_data[:languages]&.any?

    return unless all_skills.any?

    Rails.logger.info "Creating #{all_skills.length} skill tag(s)"

    all_skills.each do |skill_name|
      next if skill_name.blank?

      begin
        # Find or create skill tag
        tag = Tag.find_or_create_skill(skill_name)

        # Create tag resource association if it doesn't exist
        unless profile.tag_resources.exists?(tag_id: tag.id)
          profile.tag_resources.create!(tag: tag)
          Rails.logger.info "Created skill tag association: #{skill_name}"
        end

      rescue StandardError => e
        Rails.logger.error "Failed to create skill tag '#{skill_name}': #{e.message}"
        # Continue processing other skills
      end
    end

    Rails.logger.info "Skill tags created successfully"
  end

  # Set cache status for tracking
  def set_cache_status(profile_id, status)
    cache_key = "profile_enhance_status_#{profile_id}"
    Rails.cache.write(cache_key, status, expires_in: CACHE_EXPIRATION)
    Rails.logger.info "Set cache status to '#{status}' for profile ID: #{profile_id}"
  end
end

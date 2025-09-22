class ResumesController < ApplicationController
  def index
  end

  def process_resume
    if params[:file].present? && params[:file].content_type == 'application/pdf'
      begin
        # Save uploaded file temporarily
        temp_file = Tempfile.new(['resume', '.pdf'])
        temp_file.binmode
        temp_file.write(params[:file].read)
        temp_file.close

        # Parse the PDF
        parser = ResumeParser.new(temp_file.path)
        profile_data = parser.parse_profile_data

        # Store in Rails cache instead of session to avoid cookie overflow
        cache_key = "profile_data_#{SecureRandom.hex(16)}"
        Rails.cache.write(cache_key, profile_data, expires_in: 1.hour)
        session[:profile_cache_key] = cache_key

        # Clean up temp file
        temp_file.unlink

        redirect_to result_path
      rescue => e
        Rails.logger.error "PDF parsing error: #{e.message}"
        redirect_to root_path, alert: 'Error processing PDF. Please try again or use a different file.'
      end
    else
      redirect_to root_path, alert: 'Please upload a valid PDF file'
    end
  end

  def result
    cache_key = session[:profile_cache_key]
    @profile_data = Rails.cache.read(cache_key) if cache_key

    if @profile_data.nil?
      redirect_to root_path, alert: 'No data found. Please upload a resume first.'
    end
  end

  def update_profile
    cache_key = session[:profile_cache_key]
    profile_data = Rails.cache.read(cache_key) if cache_key

    if profile_data
      # Handle profile image upload
      if params[:profile_image].present?
        uploaded_file = params[:profile_image]
        if uploaded_file.content_type.start_with?('image/')
          # Generate unique filename
          filename = "#{SecureRandom.hex(16)}_#{uploaded_file.original_filename}"
          file_path = Rails.root.join('public', 'uploads', 'profile_images', filename)

          # Save the file
          File.open(file_path, 'wb') do |file|
            file.write(uploaded_file.read)
          end

          # Store the relative path in profile data
          profile_data["profileImageUrl"] = "/uploads/profile_images/#{filename}"
        end
      end

      # Update the cached data with new values (excluding profile_image which we handled above)
      update_params = profile_params.except(:profile_image)
      profile_data.merge!(update_params)
      Rails.cache.write(cache_key, profile_data, expires_in: 1.hour)
      redirect_to result_path, notice: 'Profile data updated successfully!'
    else
      redirect_to root_path, alert: 'No data found. Please upload a resume first.'
    end
  end

  private

  def profile_params
    params.permit(
      :professionalSummary,
      :profile_image,
      personalInfo: [:fullName, :email, :phone, :location, :website, :linkedin]
    )
  end

  def demo_profile_data
    {
      "profileImageUrl" => nil,
      "personalInfo" => {
        "fullName" => "Sarah Johnson",
        "email" => "sarah.johnson@email.com",
        "phone" => "(555) 123-4567",
        "location" => "San Francisco, CA",
        "website" => "www.sarahjohnson.dev",
        "linkedin" => "linkedin.com/in/sarahjohnson"
      },
      "professionalSummary" => "Experienced software developer with 5+ years in full-stack development, specializing in React, Node.js, and cloud technologies. Passionate about building scalable applications and mentoring junior developers.",
      "experience" => [
        {
          "title" => "Senior Software Engineer",
          "company" => "TechCorp Inc.",
          "location" => "San Francisco, CA",
          "startDate" => "Jan 2022",
          "endDate" => "Present",
          "description" => "Lead development of customer-facing web applications serving 100K+ users",
          "keyAchievements" => ["Improved app performance by 40%", "Led team of 4 developers", "Implemented CI/CD pipeline"]
        },
        {
          "title" => "Software Developer",
          "company" => "StartupXYZ",
          "location" => "San Francisco, CA",
          "startDate" => "Jun 2020",
          "endDate" => "Dec 2021",
          "description" => "Developed and maintained full-stack applications using React and Node.js",
          "keyAchievements" => ["Built 3 major features from scratch", "Reduced bug reports by 60%"]
        }
      ],
      "education" => [
        {
          "degree" => "B.S. Computer Science",
          "institution" => "University of California, Berkeley",
          "graduationYear" => "2020",
          "gpa" => "3.7",
          "honors" => "Magna Cum Laude"
        }
      ],
      "skills" => {
        "technical" => ["JavaScript", "React", "Node.js", "Python", "AWS", "Docker"],
        "soft" => ["Leadership", "Communication", "Problem Solving", "Team Collaboration"],
        "languages" => ["English (Native)", "Spanish (Conversational)"]
      },
      "certifications" => [
        {
          "name" => "AWS Solutions Architect",
          "issuer" => "Amazon Web Services",
          "date" => "2023"
        }
      ],
      "projects" => [
        {
          "name" => "E-commerce Platform",
          "description" => "Built a full-stack e-commerce platform with React, Node.js, and PostgreSQL",
          "technologies" => ["React", "Node.js", "PostgreSQL", "Stripe API"]
        }
      ]
    }
  end
end
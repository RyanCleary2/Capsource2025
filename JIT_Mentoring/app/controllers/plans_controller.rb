class PlansController < ApplicationController
  # GET /
  # Displays the index page where users can input a website URL and select case options.
  def index
  end

  # POST /generate_mentorship_plan
  # Generates a mentorship plan based on user inputs (no website required).
  def generate_mentorship_plan
    mentee_goal = params[:mentee_goal]
    mentee_background = params[:mentee_background]
    mentee_interests = params[:mentee_interests] || []
    mentor_industry = params[:mentor_industry]
    mentor_expertise = params[:mentor_expertise] || []
    mentor_style = params[:mentor_style]
    relationship_duration = params[:relationship_duration]
    session_frequency = params[:session_frequency]

    if mentee_goal.blank? || mentee_background.blank? || mentee_interests.empty? || mentor_industry.blank? || mentor_expertise.empty? || mentor_style.blank? || relationship_duration.blank? || session_frequency.blank?
      flash.now[:alert] = "Please fill in all mentorship plan fields."
      return render :index
    end

    client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
    @mentorship_plan = generate_mentorship_plan_content(
      client,
      mentee_goal,
      mentee_background,
      mentee_interests,
      mentor_industry,
      mentor_expertise,
      mentor_style,
      relationship_duration,
      session_frequency
    )
    @mode = "mentorship_plan"

    if @mentorship_plan.present?
      render :result
    else
      flash.now[:alert] = "OpenAI request failed or returned empty content. Check your logs."
      render :index
    end
  end

  # POST /generate_mentorship_plan_from_idea
  # Generates a mentorship plan based on a user-provided theme/idea and mentorship plan fields (no website required).
  def generate_mentorship_plan_from_idea
    idea = params[:case_idea]
    @mode = "mentorship_plan"

    mentee_goal = params[:mentee_goal]
    mentee_background = params[:mentee_background]
    mentee_interests = params[:mentee_interests] || []
    mentor_industry = params[:mentor_industry]
    mentor_expertise = params[:mentor_expertise] || []
    mentor_style = params[:mentor_style]
    relationship_duration = params[:relationship_duration]
    session_frequency = params[:session_frequency]

    if idea.blank? || mentee_goal.blank? || mentee_background.blank? || mentee_interests.empty? || mentor_industry.blank? || mentor_expertise.empty? || mentor_style.blank? || relationship_duration.blank? || session_frequency.blank?
      flash.now[:alert] = "Please fill in all mentorship plan fields and provide a theme or idea."
      return render :index
    end

    client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
    @mentorship_plan = generate_mentorship_plan_content(
      client,
      mentee_goal,
      mentee_background,
      mentee_interests,
      mentor_industry,
      mentor_expertise,
      mentor_style,
      relationship_duration,
      session_frequency,
      idea
    )

    if @mentorship_plan.present?
      render :result
    else
      flash.now[:alert] = "OpenAI request failed or returned empty content. Check your logs."
      render :index
    end
  end

  private

  # Generates a detailed mentorship plan using the OpenAI API based on all provided fields (no website context).
  def generate_mentorship_plan_content(client, mentee_goal, mentee_background, mentee_interests, mentor_industry, mentor_expertise, mentor_style, relationship_duration, session_frequency, idea=nil)
    prompt = <<~PROMPT
      Mentorship Plan Context:

      Mentee Goal: #{mentee_goal}
      Mentee Background: #{mentee_background}
      Mentee Interest Topics: #{mentee_interests.join(', ')}

      Mentor Industry/Role: #{mentor_industry}
      Mentor Areas of Expertise: #{mentor_expertise.join(', ')}
      Mentor Preferred Mentorship Style: #{mentor_style}

      Relationship Duration: #{relationship_duration}
      Session Frequency: #{session_frequency}

      #{idea.present? ? "Mentorship Theme or Focus: #{idea}" : ""}

      Generate a detailed Mentorship Plan for this pairing. The plan should include:
      1. Pre-Meeting Assignment: Define expectations, set goals, include a short reflection prompt about the topic, and prepare the student for their first discussion with the mentor.
      2. Meeting Schedule: List the number of meetings (based on duration/frequency), and for each meeting, provide 4–6 conversation starters or guiding questions tailored to the mentee's goal, background, and interests, and the mentor's expertise and style.
      3. For each meeting, suggest a small action item or reflection for the mentee to complete before the next session.
      4. Make the plan actionable, engaging, and personalized. Avoid generic advice. Ensure the plan is realistic for the given duration and frequency.
      5. Format the response clearly with headings for each section.
      6. Everything must be original content.
    PROMPT

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 1800,
        temperature: 0.7
      }
    )
    response.dig("choices", 0, "message", "content")&.strip
  rescue => e
    Rails.logger.error "OpenAI error in mentorship plan: #{e.message}"
    nil
  end
end
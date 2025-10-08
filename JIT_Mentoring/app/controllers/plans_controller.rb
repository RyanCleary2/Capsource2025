class PlansController < ApplicationController
  # GET /
  # Displays the index page where users can input a website URL and select case options.
  def index
  end

  # POST /generate_mentorship_plan
  # Generates a mentorship plan based on user inputs (no website required).
  def generate_mentorship_plan
  # New simplified flow: accept only a single goal statement
  goal_statement = params[:mentee_goal]

    if goal_statement.blank?
      flash.now[:alert] = "Please provide a goal statement for the mentorship plan."
      return render :index
    end

    client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
    @mentorship_plan = generate_mentorship_plan_content_from_goal(client, goal_statement)

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
  # Treat the provided idea as a goal statement and reuse the simplified flow
  idea = params[:case_idea]

    if idea.blank?
      flash.now[:alert] = "Please provide a theme or goal statement."
      return render :index
    end

    client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
    @mentorship_plan = generate_mentorship_plan_content_from_goal(client, idea)

    if @mentorship_plan.present?
      render :result
    else
      flash.now[:alert] = "OpenAI request failed or returned empty content. Check your logs."
      render :index
    end
  end

  private

  # Generates a detailed mentorship plan using the OpenAI API based on all provided fields (no website context).
  def generate_mentorship_plan_content_from_goal(client, goal_statement)
    # Improved prompt: infer appropriate duration and session frequency from the goal (default 6 weeks, weekly)
    prompt = <<~PROMPT
      Mentorship Plan Goal: "#{goal_statement}"

      Context and requirements:
      - Infer an appropriate mentorship duration and session frequency from the goal. If unsure, default to a 6 meeting program, no more than 8 meetings.
      - Provide a clear Pre-Meeting Assignment that sets expectations, defines short-term and long-term goals, and includes preparatory work for the mentee.
      - Divide the plan into meetings. For each meeting provide tailored conversation starters / guiding questions, a suggested deliverable, this may include getting exposure for upcoming meetings or applying what was discussed previously.
      - Use an amount of conversation starters/questions that seems appropriate for each meeting and across the plan — do not exceed a total of 6 questions each meeting.
      - Ensure the mentor can leverage domain expertise to guide tasks. Pre-meeting assignments should be brief, experiential, thought-provoking, and produce artifacts that demonstrate progress.
      - After each meeting, suggest a deliverable that captures key takeaways and evidence of learning (e.g., an updated resume, a LinkedIn message, a mock interview recording, a one-page reflection).
      - Avoid generic advice. Personalize suggestions to common career-development, skill, or personal growth contexts (internships, career transitions, experiences).
      - Format the response with headings: Plan Title (short), Pre-Meeting Assignment, Meeting 1..N, Questions, Deliverable), a short Summary, and resource links if applicable.
      - Keep the Pre-Meeting Assignment should be an interesting learning experience that is concise and asynchronous-friendly.

      Generate the mentorship plan now.
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
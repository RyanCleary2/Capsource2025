# FieldPlacementController handles field-placement actions, generating ideas and scopes
# based on user inputs (objective statement, discipline, selected topics, website URL).
class FieldPlacementController < ApplicationController
  include DisciplineTopicsHelper
  # Make parsing/formatting helpers available to views
  helper FieldPlacementHelper

  # GET /
  # Displays the index page where users can input organization/website and field placement options.
  def index
  end

  # POST /generate_field_placement
  # Generates either field placement ideas or a full field placement scope based on user inputs.
  def generate_field_placement
    discipline = params[:discipline].presence

    objective = params[:background]
    if objective.blank?
      flash.now[:alert] = "Missing objective statement"
      return render :index
    end

    topics = map_topic_slugs_to_labels(params[:topics] || [])

    unless ENV['OPENAI_API_KEY'].present?
      Rails.logger.error "OPENAI_API_KEY is missing. Set ENV['OPENAI_API_KEY'] before calling OpenAI."
      flash.now[:alert] = "Server is not configured to call OpenAI (missing API key). Check server logs."
      return render :index
    end

    client = OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])
    # Generate prompt and call OpenAI, but log debug info to help troubleshoot empty responses
    begin
      @field_placement_scope = generate_field_placement_scope(client, objective, discipline, topics)
      Rails.logger.debug "FieldPlacement prompt built for discipline=#{discipline.inspect} topics=#{topics.inspect}"
    rescue => e
      Rails.logger.error "OpenAI client call raised: #{e.class} - #{e.message}\n#{e.backtrace.take(10).join("\n")}" unless Rails.env.production?
      @field_placement_scope = nil
    end
    @mode = "scope"

    # The result view expects `@case_scope` (legacy name). Mirror the generated scope so the view renders it.
    @case_scope = @field_placement_scope

    if @field_placement_scope.present?
      render :result
    else
      flash.now[:alert] = "OpenAI request failed or returned empty content. Check your logs."
      render :index
    end

  end

  private

  def generate_field_placement_scope(client, objective, discipline = nil, topics = [])
    # Build human-readable text for discipline and topics
    discipline_text = discipline.present? ? "Discipline: #{discipline}." : ""
    topics_text = topics.present? ? "Topics: #{topics.join(', ')}." : ""
    objective_text = objective.present? ? "Field Placement Objective Statement: \"#{objective}\"." : ""

    prompt = <<~PROMPT
    Before taking any user input check that the input is safe and does not contain harmful content. If the input is unsafe, return an error message instead of proceeding.
    You are a helpful assistant that creates original and engaging Field Placement scopes for students based on the provided objective, discipline, and topics:
    #{objective_text}
    #{discipline_text}
    #{topics_text}

    Make sure the placement is relevant to the discipline and the provided objective. 
    The scope should be detailed and actionable, include:
    a title,
    a 250-300 word background and objective section that describes the opportunity and how a student will learn and contribute within their time,
    Field Placement Responsibilities (numbered list) which includes key tasks, duties, and projects the student will undertake,
    and Learning Outcomes (Bulleted List) which includes the intended learning outcomes for students.

    Format like this:
    Title: [Field Placement Title] ENDS HERE
    Description: [Background and Objective] ENDS HERE
    Field Placement Responsibilities: [Placement List] ENDS HERE
    Learning Outcomes: [Outcome List] ENDS HERE

    Everything must be original content, do not copy from any provided website. All tasks must be realistic and achievable for a student and able to be completed asynchronously.
    PROMPT

    Rails.logger.debug "Calling OpenAI with prompt:\n#{prompt[0..1000]}" if Rails.logger.debug?
    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 1500,
        temperature: 0.7
      }
    )

    # Log the raw response for debugging (debug level only)
    Rails.logger.debug "OpenAI raw response: #{response.to_h.inspect[0..2000]}" if Rails.logger.debug?

    content = response.dig("choices", 0, "message", "content")&.strip
    if content.blank?
      Rails.logger.warn "OpenAI returned empty content for prompt. Response keys: #{response.keys.inspect}"
    end
    content
  rescue => e
    Rails.logger.error "OpenAI error in field placement scope: #{e.class} - #{e.message}\n#{e.backtrace.take(10).join("\n") }"
    nil
  end
end
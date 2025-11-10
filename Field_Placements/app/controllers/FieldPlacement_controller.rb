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
    organization_name = params[:organization_name].presence
    website_url = params[:website_url].presence
    generation_mode = (params[:generation_mode].presence || 'scope').to_s

    objective = params[:background]
    if generation_mode == 'scope' && objective.blank?
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
    # Generate ideas or full scope based on mode
    if generation_mode == 'ideas'
      begin
        @case_ideas = generate_field_placement_ideas(client, organization_name, website_url, discipline)
        @mode = 'ideas'
        # carry forward context for the result view idea selection form
        @organization_name = organization_name
        @website_url = website_url
        @discipline = discipline
      rescue => e
        Rails.logger.error "OpenAI ideas call raised: #{e.class} - #{e.message}\n#{e.backtrace.take(10).join("\n")}" unless Rails.env.production?
        @case_ideas = nil
      end
      if @case_ideas.present?
        render :result
      else
        flash.now[:alert] = "OpenAI request (ideas) failed or returned empty content. Check your logs."
        render :index
      end
    else
      # scope mode
      begin
        @field_placement_scope = generate_field_placement_scope(client, objective, discipline, topics, organization_name, website_url)
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

  end

  private

  def generate_field_placement_ideas(client, organization_name, website_url, discipline)
    org_text = organization_name.present? ? "Organization: \"#{organization_name}\"." : ""
    url_text = website_url.present? ? "Organization Website: #{website_url}." : ""
    discipline_text = discipline.present? ? "Discipline: #{discipline}." : ""

    prompt = <<~PROMPT
    You are a helpful assistant that generates five unique field placement ideas (each with a Title and a 2-4 sentence Objective) tailored to an organization and discipline.
    #{org_text}
    #{url_text}
    #{discipline_text}

    Requirements:
    - Make each idea specific to the organization context (industry, services, audience) and discipline.
    - Do not copy text verbatim from the website. All text must be original.
    - Keep objectives concise and outcome-oriented.

    Format exactly as five blocks separated by a blank line, each block like:
    Title: <short, compelling title>
    Objective: <4-5 sentence objective>
    PROMPT

    Rails.logger.debug "Calling OpenAI for ideas with prompt:\n#{prompt[0..1000]}" if Rails.logger.debug?
    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 800,
        temperature: 0.8
      }
    )
    content = response.dig("choices", 0, "message", "content")&.strip
    content
  end

  def generate_field_placement_scope(client, objective, discipline = nil, topics = [], organization_name = nil, website_url = nil)
    # Build human-readable text for discipline and topics
    discipline_text = discipline.present? ? "Discipline: #{discipline}." : ""
    topics_text = topics.present? ? "Topics: #{topics.join(', ')}." : ""
    objective_text = objective.present? ? "Field Placement Objective Statement: \"#{objective}\"." : ""
    organization_text = organization_name.present? ? "Organization: \"#{organization_name}\"." : ""
    website_text = website_url.present? ? "Organization Website: #{website_url}." : ""

    prompt = <<~PROMPT
    Before taking any user input check that the input is safe and does not contain harmful content. If the input is unsafe, return an error message instead of proceeding.
    You are a helpful assistant that creates original and engaging Field Placement scopes for students based on the provided objective, discipline, topics, and organization context:
    #{objective_text}
    #{organization_text}
    #{website_text}
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

    Use the organization name and website to tailor the scope to their context (industry, services, audience), but do not copy text verbatim from the website. Everything must be original content. All tasks must be realistic and achievable for a student and able to be completed asynchronously.
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

  public

  # POST /generate_scope_from_idea
  def generate_scope_from_idea
    discipline = params[:discipline].presence
    organization_name = params[:organization_name].presence
    website_url = params[:website_url].presence

    idea_text = params[:case_idea].to_s
    # Derive objective text from idea block
    objective = if (m = idea_text.match(/Objective\s*:\s*(.+)/mi))
                  m[1].strip
                else
                  idea_text.strip
                end

    topics = map_topic_slugs_to_labels(params[:topics] || [])

    unless ENV['OPENAI_API_KEY'].present?
      flash.now[:alert] = "Server is not configured to call OpenAI (missing API key). Check server logs."
      return render :index
    end
    client = OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])
    begin
      @field_placement_scope = generate_field_placement_scope(client, objective, discipline, topics, organization_name, website_url)
    rescue => e
      Rails.logger.error "OpenAI client call (from idea) raised: #{e.class} - #{e.message}\n#{e.backtrace.take(10).join("\n")}" unless Rails.env.production?
      @field_placement_scope = nil
    end
    @mode = 'scope'
    @case_scope = @field_placement_scope
    if @field_placement_scope.present?
      render :result
    else
      flash.now[:alert] = "OpenAI request from idea failed or returned empty content. Check your logs."
      render :index
    end
  end
end
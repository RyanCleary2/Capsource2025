# app/controllers/projects_controller.rb

class ProjectsController < ApplicationController
  # GET /
  def index
  end

  # POST /generate_project
  def generate_project
    url  = params[:website_url]
    mode = params[:mode] || "scope"

    @website_url = url

    if url.blank?
      flash.now[:alert] = "Missing website URL"
      return render :index
    end

    client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))

    if mode == "ideas"
      topics = params[:topics] || []
      if topics.empty?
        flash.now[:alert] = "Please select at least one topic for project ideas"
        return render :index
      end
      @project_ideas = generate_project_ideas(client, url, topics)
      @mode          = "ideas"
    else
      goal = params[:background]
      if goal.blank?
        flash.now[:alert] = "Missing goal statement"
        return render :index
      end
      @project_scope = generate_project_scope(client, url, goal)
      @mode           = "scope"
    end

    if (@mode == "ideas" && @project_ideas.present?) || (@mode == "scope" && @project_scope.present?)
      render :result
    else
      flash.now[:alert] = "OpenAI request failed or returned empty content. Check your logs."
      render :index
    end
  end

  # POST /generate_scope_from_idea
  def generate_scope_from_idea
    url  = params[:website_url]
    idea = params[:project_idea]

    @website_url = url
    @mode        = "scope"

    if url.blank? || idea.blank?
      flash.now[:alert] = "Missing website URL or project idea"
      return render :index
    end

    client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
    @project_scope = generate_project_scope(client, url, idea)

    if @project_scope.present?
      render :result
    else
      flash.now[:alert] = "OpenAI request failed or returned empty content. Check your logs."
      render :index
    end
  end

  private

  def generate_project_ideas(client, url, topics)
    prompt = <<~PROMPT
      Given the company website: #{url}, and the selected topics: #{topics.join(', ')},
      generate 3–5 concise project ideas (50–100 words each) that align with the company's context
      and the selected topics. Each idea should include:
      - A title
      - A brief description
      Format the response as a numbered list.
    PROMPT

    response = client.chat(
      parameters: {
        model:       "gpt-4o-mini",
        messages:    [{ role: "user", content: prompt }],
        max_tokens:  500,
        temperature: 0.8
      }
    )
    response.dig("choices", 0, "message", "content")&.strip
  rescue => e
    Rails.logger.error "OpenAI error in ideas: #{e.message}"
    nil
  end

  def generate_project_scope(client, url, goal)
    prompt = <<~PROMPT
      Given the company website: #{url}, and their goal: "#{goal}", generate a full CapSource project scope with the following structure:
      Project Title
      Challenge/Opportunity (150–200 words)
      Action Items (bulleted list)
      Measuring Success (bulleted list)
      Topics Covered (bulleted list)
      Milestones 1–5 (title, guiding questions, suggested deliverables)
      Helpful Public Resources (links + 1-line description)
    PROMPT

    response = client.chat(
      parameters: {
        model:       "gpt-4o-mini",
        messages:    [{ role: "user", content: prompt }],
        max_tokens:  1000,
        temperature: 0.7
      }
    )
    response.dig("choices", 0, "message", "content")&.strip
  rescue => e
    Rails.logger.error "OpenAI error in scope: #{e.message}"
    nil
  end
end
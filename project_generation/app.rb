# app/controllers/projects_controller.rb

class ProjectsController < ApplicationController
  # Render the homepage form
  def index
  end

  # Handle project generation (ideas or full scope)
  def generate_project
    url  = params[:website_url]
    mode = params[:mode] || "scope"

    if url.blank?
      flash.now[:alert] = "Missing website URL"
      return render :index
    end

    client = OpenAI::Client.new

    if mode == "ideas"
      topics = params[:topics] || []
      if topics.empty?
        flash.now[:alert] = "Please select at least one topic for project ideas"
        return render :index
      end
      @result = generate_project_ideas(client, url, topics)
      @mode   = "ideas"
    else
      goal = params[:background]
      if goal.blank?
        flash.now[:alert] = "Missing goal statement"
        return render :index
      end
      @result = generate_project_scope(client, url, goal)
      @mode   = "scope"
    end

    if @result
      render :result
    else
      flash.now[:alert] = "OpenAI request failed. Check your logs."
      render :index
    end
  end

  # Generate a full scope from a selected idea
  def generate_scope_from_idea
    url  = params[:website_url]
    idea = params[:project_idea]

    if url.blank? || idea.blank?
      flash.now[:alert] = "Missing website URL or project idea"
      return render :index
    end

    client = OpenAI::Client.new
    @result = generate_project_scope(client, url, idea)
    @mode   = "scope"

    if @result
      render :result
    else
      flash.now[:alert] = "OpenAI request failed. Check your logs."
      render :index
    end
  end

  private

  # Calls OpenAI to generate project ideas
  def generate_project_ideas(client, url, topics)
    prompt = <<~PROMPT
      Given the company website: #{url}, and the selected topics: #{topics.join(', ')},
      generate 3-5 concise project ideas (50-100 words each) that align with the company's context
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

  # Calls OpenAI to generate full project scope
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
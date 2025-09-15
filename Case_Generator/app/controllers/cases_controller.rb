# CasesController handles case-related actions, including generating case ideas and scopes
# based on user-provided website URLs and specific inputs. It interacts with the OpenAI API to
# produce tailored case content and renders appropriate views based on the results.
class CasesController < ApplicationController
  # GET /
  # Displays the index page where users can input a website URL and select case options.
  def index
  end

  # POST /generate_case
  # Generates either case ideas or a case scope based on user inputs.
  # Expects parameters: website_url (string), mode (boolean string), topics (array), and background (string).
  def generate_case
    url = params[:website_url]
    mode = params[:mode] == "true" ? "ideas" : "scope"

    @website_url = url

    if url.blank?
      flash.now[:alert] = "Missing website URL"
      return render :index
    end

    client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))

    if mode == "ideas"
      topics = params[:topics] || []
      if topics.empty?
        flash.now[:alert] = "Please select at least one topic for case ideas"
        return render :index
      end
      @case_ideas = generate_case_ideas(client, url, topics)
      @mode = "ideas"
    else
      objective = params[:background]
      if objective.blank?
        flash.now[:alert] = "Missing objective statement"
        return render :index
      end
      @case_scope = generate_case_scope(client, url, objective)
      @mode = "scope"
    end

    if (@mode == "ideas" && @case_ideas.present?) || (@mode == "scope" && @case_scope.present?)
      render :result
    else
      flash.now[:alert] = "OpenAI request failed or returned empty content. Check your logs."
      render :index
    end
  end

  # POST /generate_scope_from_idea
  # Generates a case scope based on a user-provided case idea and website URL.
  # Expects parameters: website_url (string) and case_idea (string).
  def generate_scope_from_idea
    url = params[:website_url]
    idea = params[:case_idea]

    @website_url = url
    @mode = "scope"

    if url.blank? || idea.blank?
      flash.now[:alert] = "Missing website URL or case idea"
      return render :index
    end

    client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
    @case_scope = generate_case_scope(client, url, idea)

    if @case_scope.present?
      render :result
    else
      flash.now[:alert] = "OpenAI request failed or returned empty content. Check your logs."
      render :index
    end
  end

  private

  # Generates case ideas using the OpenAI API based on a website URL and selected topics.
  def generate_case_ideas(client, url, topics)
    formatted_topics = topics.map { |t| t.gsub('-', ' ').titleize }
    prompt = <<~PROMPT
      Given the company website: #{url}, and the selected topics: #{formatted_topics.join(', ')},
      generate 3–5 concise case ideas (50–100 words each) that align with the company's context
      and the selected topics. Each idea should include:
      - Case Title
      - Brief Background and Objective
      - Key Action Items (bulleted list)
      - Ways to Measure Success (bulleted list)
      Format the response as a numbered list.
    PROMPT

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 500,
        temperature: 0.8
      }
    )
    response.dig("choices", 0, "message", "content")&.strip
  rescue => e
    Rails.logger.error "OpenAI error in case ideas: #{e.message}"
    nil
  end

  # Generates a detailed case scope using the OpenAI API based on a website URL and objective/idea.
  def generate_case_scope(client, url, objective)
    prompt = <<~PROMPT
      Given the company website: #{url}, and their objective: "#{objective}", generate a full Case Generator scope with the following structure:

      Case Title

      Background and Objective (150–200 words)

      Key Action Items (bulleted list)

      Ways to Measure Success (bulleted list)

      Milestones 1–4 (for each milestone: provide a title, 5 guiding questions, and a suggested deliverable)
    PROMPT

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 1000,
        temperature: 0.7
      }
    )
    response.dig("choices", 0, "message", "content")&.strip
  rescue => e
    Rails.logger.error "OpenAI error in case scope: #{e.message}"
    nil
  end
end
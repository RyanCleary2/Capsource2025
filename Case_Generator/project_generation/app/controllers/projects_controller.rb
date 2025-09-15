# app/controllers/projects_controller.rb

# ProjectsController handles project-related actions, including generating project ideas and scopes
# based on user-provided website URLs and specific inputs. It interacts with the OpenAI API to
# produce tailored project content and renders appropriate views based on the results.
class ProjectsController < ApplicationController
  # GET /
  # Displays the index page where users can input a website URL and select project options.
  def index
  end

  # POST /generate_project
  # Generates either project ideas or a project scope based on user inputs.
  # Expects parameters: website_url (string), mode (boolean string), topics (array), and background (string).
  def generate_project
    url = params[:website_url]
    mode = params[:mode] == "true" ? "ideas" : "scope"  # Converts checkbox value to mode string

    @website_url = url

    # Validate presence of website URL
    if url.blank?
      flash.now[:alert] = "Missing website URL"
      return render :index
    end

    # Initialize OpenAI client with API key from environment variables
    client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))

    if mode == "ideas"
      topics = params[:topics] || []
      # Ensure at least one topic is selected for ideas mode
      if topics.empty?
        flash.now[:alert] = "Please select at least one topic for project ideas"
        return render :index
      end
      @project_ideas = generate_project_ideas(client, url, topics)
      @mode = "ideas"
    else
      goal = params[:background]
      # Validate presence of goal statement for scope mode
      if goal.blank?
        flash.now[:alert] = "Missing goal statement"
        return render :index
      end
      @project_scope = generate_project_scope(client, url, goal)
      @mode = "scope"
    end

    # Render result if content is generated successfully, otherwise show error
    if (@mode == "ideas" && @project_ideas.present?) || (@mode == "scope" && @project_scope.present?)
      render :result
    else
      flash.now[:alert] = "OpenAI request failed or returned empty content. Check your logs."
      render :index
    end
  end

  # POST /generate_scope_from_idea
  # Generates a project scope based on a user-provided project idea and website URL.
  # Expects parameters: website_url (string) and project_idea (string).
  def generate_scope_from_idea
    url = params[:website_url]
    idea = params[:project_idea]

    @website_url = url
    @mode = "scope"

    # Validate presence of both URL and project idea
    if url.blank? || idea.blank?
      flash.now[:alert] = "Missing website URL or project idea"
      return render :index
    end

    # Initialize OpenAI client
    client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
    @project_scope = generate_project_scope(client, url, idea)

    # Render result if scope is generated, otherwise show error
    if @project_scope.present?
      render :result
    else
      flash.now[:alert] = "OpenAI request failed or returned empty content. Check your logs."
      render :index
    end
  end

  private

  # Generates project ideas using the OpenAI API based on a website URL and selected topics.
  # @param client [OpenAI::Client] The initialized OpenAI client
  # @param url [String] The company website URL
  # @param topics [Array<String>] List of selected topic identifiers
  # @return [String, nil] Formatted project ideas or nil if the request fails
  def generate_project_ideas(client, url, topics)
    # Convert topic identifiers to human-readable format for the prompt
    formatted_topics = topics.map { |t| t.gsub('-', ' ').titleize }
    
    # Construct prompt for generating 3–5 project ideas
    prompt = <<~PROMPT
      Given the company website: #{url}, and the selected topics: #{formatted_topics.join(', ')},
      generate 3–5 concise project ideas (50–100 words each) that align with the company's context
      and the selected topics. Each idea should include:
      - A title
      - A brief description
      Format the response as a numbered list.
    PROMPT

    # Make API request to OpenAI
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
    Rails.logger.error "OpenAI error in ideas: #{e.message}"
    nil
  end

  # Generates a detailed project scope using the OpenAI API based on a website URL and goal/idea.
  # @param client [OpenAI::Client] The initialized OpenAI client
  # @param url [String] The company website URL
  # @param goal [String] The goal or project idea for the scope
  # @return [String, nil] Formatted project scope or nil if the request fails
  def generate_project_scope(client, url, goal)
    # Construct prompt for generating a structured project scope
    prompt = <<~PROMPT
      Given the company website: #{url}, and their goal: "#{goal}", generate a full CapSource project scope with the following structure:
      
      Project Title
      
      Challenge/Opportunity (150–200 words)
      
      Action Items (bulleted list)
      
      Measuring Success (bulleted list)
      
      Topics Covered (bulleted list - select from the following topics):
      Technology Commercialization, Innovation, Training & Development, Inventory Management, 
      Electrical Engineering, Mechanical Engineering, Market Research, Digital Marketing, 
      Information Technology (IT), PR & Communications, Employee and Labor Management, 
      Entrepreneurship, Child Online Safety, Cybersecurity, Civil Engineering, Child Welfare, 
      Urban Planning, Research Analysis Evaluation, Public Administration, 
      Political Organization Policy Change and Advocacy, Individual and Family Advocacy, 
      Facilitation Mediation Conflict Resolution, Economic Development, Crisis and Disaster Management, 
      Courts Corrections and Law Enforcement, Community Organization and Social Action, 
      Case Management, Substance Use Addiction and Recovery, International Affairs, 
      Reporting Financial Planning & Analysis, Talent Management, Software Design & Development, 
      Sales & Business Development, Research & Development, Quality Control, 
      Purchasing Logistics Supply Chain, Product Design & Development, Organizational Culture, 
      Operations, Mergers & Acquisitions, Marketing, Legal Regulatory Compliance, 
      Growth Strategy, Data Management, Customer Service & Account Management, 
      Corporate Social Responsibility
      
      Milestones 1–5 (title, guiding questions, suggested deliverables)
      
      Helpful Public Resources (links + 1-line description)
      
      Make sure to include at least 3-5 relevant topics from the provided list in the Topics Covered section.
    PROMPT

    # Make API request to OpenAI
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
    Rails.logger.error "OpenAI error in scope: #{e.message}"
    nil
  end
end
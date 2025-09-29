class SkillsController < ApplicationController
  before_action :set_skill, only: [:show]

  def index
    @skills = SkillDataService.search_skills(params)
    @categories = SkillDataService.categories
    @duplicates = SkillDataService.find_duplicates
    @duplicate_count = SkillDataService.duplicate_count

    # Paginate results (simple pagination)
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = 50
    start_index = (page - 1) * per_page
    @skills = @skills[start_index, per_page] || []

    @current_page = page
    @total_skills = SkillDataService.search_skills(params).count
  end

  def show
    @related_skills = SkillDataService.related_skills(@skill[:id])
  end

  def roadmap
    skill_id = params[:id].to_i
    roadmap_data = SkillDataService.skill_roadmap(skill_id)

    if roadmap_data
      render json: roadmap_data
    else
      render json: { error: 'Skill not found' }, status: :not_found
    end
  rescue => e
    Rails.logger.error "Roadmap error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: e.message }, status: :internal_server_error
  end

  def new
    @skill = {}
    @categories = SkillDataService.categories
    @skill_levels = SkillDataService.skill_levels
    render_form_notice("This is a demo interface. Skill creation is not functional with CSV data.")
  end

  def create
    redirect_to skills_path, notice: 'Skill creation is not available in CSV mode. Please use the database version for full functionality.'
  end

  def edit
    @categories = SkillDataService.categories
    @skill_levels = SkillDataService.skill_levels
    render_form_notice("This is a demo interface. Skill editing is not functional with CSV data.")
  end

  def update
    redirect_to skills_path, notice: 'Skill editing is not available in CSV mode. Please use the database version for full functionality.'
  end

  def destroy
    redirect_to skills_path, notice: 'Skill deletion is not available in CSV mode. Please use the database version for full functionality.'
  end

  private

  def set_skill
    @skill = SkillDataService.find_skill(params[:id])
    redirect_to skills_path, alert: 'Skill not found.' unless @skill
  end

  def render_form_notice(message)
    flash.now[:notice] = message
  end
end

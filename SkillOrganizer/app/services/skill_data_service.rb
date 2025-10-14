require 'csv'

class SkillDataService
  class << self
    def all_skills
      @all_skills ||= load_and_process_skills
    end

    def reload!
      @all_skills = nil
      @categories = nil
      all_skills
    end

    def find_skill(id)
      all_skills.find { |skill| skill[:id] == id.to_i }
    end

    def search_skills(params = {})
      skills = all_skills.dup

      # Search by name
      if params[:search].present?
        search_term = params[:search].downcase
        skills = skills.select { |skill| skill[:name].downcase.include?(search_term) }
      end

      # Filter by category
      if params[:category_id].present?
        skills = skills.select { |skill| skill[:category] == params[:category_id] }
      end

      # Filter by skill level
      if params[:skill_level].present?
        skills = skills.select { |skill| skill[:skill_level] == params[:skill_level] }
      end

      # Filter by tags
      if params[:tags].present?
        tag_array = params[:tags].split(',').map(&:strip)
        skills = skills.select do |skill|
          skill[:tags].any? { |tag| tag_array.include?(tag) }
        end
      end

      skills
    end

    def categories
      @categories ||= begin
        # Extract unique categories from loaded skills
        unique_categories = all_skills.map { |s| s[:parent_category] }.compact.uniq.sort

        # Convert to hash format with id and name
        categories_list = unique_categories.map do |cat|
          { id: normalize_category(cat), name: cat }
        end

        # Add 'other' category for skills without a parent category
        categories_list << { id: 'other', name: 'Other' } unless categories_list.any? { |c| c[:id] == 'other' }

        categories_list.sort_by { |c| c[:name] }
      end
    end

    def skill_levels
      ['beginner', 'intermediate', 'advanced']
    end

    def related_skills(skill_id)
      skill = find_skill(skill_id)
      return [] unless skill

      # Find skills with similar categories or tags
      all_skills.select do |s|
        s[:id] != skill_id &&
        (s[:category] == skill[:category] ||
         (s[:tags] & skill[:tags]).any?)
      end.take(5)
    end

    def find_duplicates
      duplicates = []
      skills_by_name = all_skills.group_by { |s| s[:name].downcase.strip }

      skills_by_name.each do |name, skills_list|
        if skills_list.length > 1
          duplicates << {
            name: skills_list.first[:name],
            count: skills_list.length,
            ids: skills_list.map { |s| s[:id] },
            skills: skills_list
          }
        end
      end

      duplicates.sort_by { |d| -d[:count] }
    end

    def duplicate_count
      find_duplicates.sum { |d| d[:count] - 1 }
    end

    def skill_roadmap(skill_id)
      skill = find_skill(skill_id)
      return nil unless skill

      {
        current: skill,
        prerequisites: find_prerequisites(skill),
        progressions: find_progressions(skill),
        related: find_related_skills(skill)
      }
    end

    private

    def find_prerequisites(skill)
      # Find skills in the same category with lower levels
      category_skills = all_skills.select { |s| s[:category] == skill[:category] }

      level_order = { 'beginner' => 1, 'intermediate' => 2, 'advanced' => 3 }
      current_level = level_order[skill[:skill_level]] || 2

      prerequisites = category_skills.select do |s|
        s_level = level_order[s[:skill_level]] || 2
        s_level < current_level && s[:id] != skill[:id]
      end

      # Add effort estimates
      prerequisites.map do |prereq|
        prereq.merge(
          effort_weeks: estimate_effort(prereq[:skill_level], skill[:skill_level]),
          similarity_score: calculate_similarity(prereq, skill)
        )
      end.sort_by { |s| -s[:similarity_score] }.take(3)
    end

    def find_progressions(skill)
      # Find skills in the same category with higher levels
      category_skills = all_skills.select { |s| s[:category] == skill[:category] }

      level_order = { 'beginner' => 1, 'intermediate' => 2, 'advanced' => 3 }
      current_level = level_order[skill[:skill_level]] || 2

      progressions = category_skills.select do |s|
        s_level = level_order[s[:skill_level]] || 2
        s_level > current_level && s[:id] != skill[:id]
      end

      # Add effort estimates
      progressions.map do |prog|
        prog.merge(
          effort_weeks: estimate_effort(skill[:skill_level], prog[:skill_level]),
          similarity_score: calculate_similarity(skill, prog)
        )
      end.sort_by { |s| -s[:similarity_score] }.take(4)
    end

    def find_related_skills(skill)
      # Find skills with similar tags or in same domain
      related = all_skills.select do |s|
        s[:id] != skill[:id] && (
          s[:domain] == skill[:domain] ||
          (s[:tags] & skill[:tags]).any? ||
          s[:category] == skill[:category]
        )
      end

      related.map do |rel|
        rel.merge(similarity_score: calculate_similarity(skill, rel))
      end.sort_by { |s| -s[:similarity_score] }.take(6)
    end

    def calculate_similarity(skill1, skill2)
      score = 0.0

      # Category match (40%)
      score += 0.4 if skill1[:category] == skill2[:category]

      # Domain match (20%)
      score += 0.2 if skill1[:domain] == skill2[:domain]

      # Tag overlap (30%)
      if skill1[:tags].any? && skill2[:tags].any?
        overlap = (skill1[:tags] & skill2[:tags]).size
        max_tags = [skill1[:tags].size, skill2[:tags].size].max
        score += 0.3 * (overlap.to_f / max_tags)
      end

      # Name similarity (10%) - simple keyword matching
      name1_words = skill1[:name].downcase.split
      name2_words = skill2[:name].downcase.split
      common_words = (name1_words & name2_words).size
      if common_words > 0
        score += 0.1 * (common_words.to_f / [name1_words.size, name2_words.size].max)
      end

      (score * 100).round
    end

    def estimate_effort(from_level, to_level)
      level_order = { 'beginner' => 1, 'intermediate' => 2, 'advanced' => 3 }
      from = level_order[from_level] || 2
      to = level_order[to_level] || 2

      diff = (to - from).abs
      case diff
      when 0 then 2
      when 1 then 4
      when 2 then 8
      else 12
      end
    end

    def load_and_process_skills
      csv_file = Rails.root.join('skills_categorized.csv')
      skills = []
      row_counter = 0

      # Use BOM|UTF-8 to handle Byte Order Mark in CSV file
      CSV.foreach(csv_file, headers: true, encoding: 'BOM|UTF-8') do |row|
        skill_name = normalize_skill_name(row['Name'])
        next if skill_name.blank?

        # Skip duplicates (case insensitive)
        next if skills.any? { |s| s[:name].downcase == skill_name.downcase }

        row_counter += 1
        # Get ID from CSV or use counter if ID is missing/invalid
        csv_id = row['Id']&.strip&.to_i
        skill_id = (csv_id && csv_id > 0) ? csv_id : row_counter

        # Use Parent category from CSV if available, otherwise auto-categorize
        parent_category = row['Parent category']&.strip
        category = parent_category.present? ? normalize_category(parent_category) : categorize_skill(skill_name)

        skill = {
          id: skill_id,
          name: skill_name,
          description: generate_description(skill_name),
          category: category,
          parent_category: parent_category,
          skill_level: determine_skill_level(skill_name),
          domain: extract_domain(skill_name),
          partner: row['Partner'],
          tags: generate_tags(skill_name),
          created_at: parse_date(row['Created at']),
          updated_at: parse_date(row['Updated at'])
        }

        skills << skill
      end

      skills.sort_by { |s| s[:name] }
    end

    def normalize_skill_name(name)
      return nil if name.blank?

      name = name.to_s.strip
      name = name.gsub(/^["']|["']$/, '') # Remove quotes
      return nil if name.downcase == 'skills' || name.match?(/\d{4}-\d{2}-\d{2}/)
      return nil if name.length > 100

      name = name.gsub(/\s+/, ' ').strip
      name.split(' ').map(&:capitalize).join(' ')
    end

    def categorize_skill(skill_name)
      skill_lower = skill_name.downcase

      return 'programming' if ['python', 'java', 'javascript', 'c++', 'c#', 'php', 'ruby', 'programming'].any? { |kw| skill_lower.include?(kw) }
      return 'data-analytics' if ['data', 'analytics', 'sql', 'tableau', 'excel', 'analysis', 'machine learning', 'ai'].any? { |kw| skill_lower.include?(kw) }
      return 'engineering' if ['cad', 'solidworks', 'autocad', 'engineering', 'mechanical', 'design'].any? { |kw| skill_lower.include?(kw) }
      return 'web-dev' if ['html', 'css', 'react', 'api', 'web', 'frontend', 'backend'].any? { |kw| skill_lower.include?(kw) }
      return 'devops' if ['docker', 'aws', 'git', 'linux', 'deployment'].any? { |kw| skill_lower.include?(kw) }
      return 'business' if ['strategy', 'business', 'management', 'consulting', 'financial'].any? { |kw| skill_lower.include?(kw) }
      return 'marketing' if ['marketing', 'sales', 'advertising', 'campaign'].any? { |kw| skill_lower.include?(kw) }
      return 'communication' if ['communication', 'presentation', 'writing', 'teamwork'].any? { |kw| skill_lower.include?(kw) }
      return 'project-mgmt' if ['project management', 'agile', 'scrum'].any? { |kw| skill_lower.include?(kw) }
      return 'research' if ['research', 'survey', 'analysis'].any? { |kw| skill_lower.include?(kw) }

      'other'
    end

    def determine_skill_level(skill_name)
      skill_lower = skill_name.downcase

      return 'beginner' if ['basic', 'fundamental', 'intro', 'beginner'].any? { |word| skill_lower.include?(word) }
      return 'advanced' if ['advanced', 'expert', 'senior', 'lead'].any? { |word| skill_lower.include?(word) }

      'intermediate'
    end

    def extract_domain(skill_name)
      skill_lower = skill_name.downcase

      return 'Technology' if ['programming', 'software', 'web', 'data', 'ai'].any? { |word| skill_lower.include?(word) }
      return 'Engineering' if ['engineering', 'mechanical', 'design'].any? { |word| skill_lower.include?(word) }
      return 'Business' if ['business', 'management', 'strategy', 'marketing'].any? { |word| skill_lower.include?(word) }

      'General'
    end

    def generate_tags(skill_name)
      tags = []
      skill_lower = skill_name.downcase

      tags << 'Python Ecosystem' if skill_lower.include?('python')
      tags << 'Data Science' if ['data', 'analytics', 'science'].any? { |word| skill_lower.include?(word) }
      tags << 'CAD Software' if ['cad', 'solidworks', 'autocad'].any? { |word| skill_lower.include?(word) }
      tags << 'Microsoft Office' if ['excel', 'office', 'powerpoint'].any? { |word| skill_lower.include?(word) }
      tags << 'Programming' if ['programming', 'coding', 'development'].any? { |word| skill_lower.include?(word) }

      tags
    end

    def generate_description(skill_name)
      "#{skill_name} is a valuable skill that can contribute to various projects and initiatives."
    end

    def parse_date(date_string)
      return nil if date_string.blank?

      begin
        DateTime.parse(date_string)
      rescue
        Time.current
      end
    end

    def normalize_category(category_name)
      return 'other' if category_name.blank?

      # Convert category name to a URL-friendly ID
      category_name.downcase
        .gsub(/\s+/, '-')
        .gsub(/[^a-z0-9\-]/, '')
        .gsub(/-+/, '-')
        .gsub(/^-|-$/, '')
    end
  end
end
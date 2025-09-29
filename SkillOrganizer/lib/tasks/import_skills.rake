namespace :skills do
  desc "Import skills from CSV and normalize data"
  task import_and_normalize: :environment do
    require 'csv'

    puts "Starting skills import and normalization..."

    # First, create categories
    categories = create_categories
    puts "Created #{categories.count} categories"

    # Read and process CSV
    csv_file = Rails.root.join('skillDatabase.csv')
    unless File.exist?(csv_file)
      puts "Error: skillDatabase.csv not found in project root"
      exit
    end

    skills_created = 0
    skills_skipped = 0

    CSV.foreach(csv_file, headers: true) do |row|
      skill_name = normalize_skill_name(row['Name'])

      # Skip invalid entries
      if skill_name.blank? || skill_name.downcase == 'skills'
        skills_skipped += 1
        next
      end

      # Skip if skill already exists (case insensitive)
      if Skill.where("LOWER(name) = ?", skill_name.downcase).exists?
        skills_skipped += 1
        next
      end

      # Categorize the skill
      category = categorize_skill(skill_name, categories)

      # Determine skill level
      skill_level = determine_skill_level(skill_name)

      # Create the skill
      skill = Skill.create!(
        name: skill_name,
        category: category,
        skill_level: skill_level,
        domain: extract_domain(skill_name),
        partner: row['Partner'],
        created_at: parse_date(row['Created at']),
        updated_at: parse_date(row['Updated at'])
      )

      skills_created += 1

      if skills_created % 50 == 0
        puts "Processed #{skills_created} skills..."
      end
    end

    puts "Import completed!"
    puts "Skills created: #{skills_created}"
    puts "Skills skipped: #{skills_skipped}"

    # Create skill relationships
    puts "Creating skill relationships..."
    create_skill_relationships
    puts "Skill relationships created!"
  end

  private

  def create_categories
    category_definitions = [
      {
        name: 'Programming Languages',
        description: 'Programming languages and scripting technologies'
      },
      {
        name: 'Data & Analytics',
        description: 'Data science, analytics, and business intelligence skills'
      },
      {
        name: 'Engineering & CAD',
        description: 'Engineering design, CAD software, and technical skills'
      },
      {
        name: 'Web Development',
        description: 'Frontend, backend, and full-stack web development'
      },
      {
        name: 'DevOps & Tools',
        description: 'Development tools, deployment, and infrastructure'
      },
      {
        name: 'Business Strategy',
        description: 'Business analysis, strategy, and consulting skills'
      },
      {
        name: 'Marketing & Sales',
        description: 'Marketing, advertising, and sales-related skills'
      },
      {
        name: 'Communication & Soft Skills',
        description: 'Communication, presentation, and interpersonal skills'
      },
      {
        name: 'Project Management',
        description: 'Project management methodologies and tools'
      },
      {
        name: 'Research & Analysis',
        description: 'Research methodologies and analytical skills'
      },
      {
        name: 'Other',
        description: 'Miscellaneous skills not fitting other categories'
      }
    ]

    categories = {}
    category_definitions.each do |cat_def|
      category = Category.find_or_create_by(name: cat_def[:name]) do |c|
        c.description = cat_def[:description]
      end
      categories[cat_def[:name]] = category
    end

    categories
  end

  def normalize_skill_name(name)
    return nil if name.blank?

    # Convert to string and clean
    name = name.to_s.strip

    # Remove quotes
    name = name.gsub(/^["']|["']$/, '')

    # Skip if it's just "skills" or contains timestamps
    return nil if name.downcase == 'skills' || name.match?(/\d{4}-\d{2}-\d{2}/)

    # Skip if too long (likely corrupted data)
    return nil if name.length > 100

    # Basic cleaning
    name = name.gsub(/\s+/, ' ').strip

    # Capitalize properly
    name = name.split(' ').map(&:capitalize).join(' ')

    name.blank? ? nil : name
  end

  def categorize_skill(skill_name, categories)
    skill_lower = skill_name.downcase

    # Programming Languages
    programming_keywords = ['python', 'java', 'javascript', 'c++', 'c#', 'php', 'ruby', 'go', 'rust', 'kotlin', 'swift', 'scala', 'programming']
    return categories['Programming Languages'] if programming_keywords.any? { |kw| skill_lower.include?(kw) }

    # Data & Analytics
    data_keywords = ['data', 'analytics', 'sql', 'tableau', 'powerbi', 'excel', 'pandas', 'numpy', 'matplotlib', 'seaborn', 'analysis', 'mining', 'science', 'machine learning', 'ai', 'artificial intelligence', 'statistics', 'statistical']
    return categories['Data & Analytics'] if data_keywords.any? { |kw| skill_lower.include?(kw) }

    # Engineering & CAD
    engineering_keywords = ['cad', 'solidworks', 'autocad', 'fusion', 'ansys', 'comsol', 'mechanical', 'engineering', 'design', 'manufacturing', 'cnc', 'gd&t', '3d printing', 'kinematics', 'dynamics']
    return categories['Engineering & CAD'] if engineering_keywords.any? { |kw| skill_lower.include?(kw) }

    # Web Development
    web_keywords = ['html', 'css', 'react', 'angular', 'vue', 'node', 'express', 'django', 'flask', 'api', 'rest', 'web', 'frontend', 'backend', 'fullstack', 'json', 'http']
    return categories['Web Development'] if web_keywords.any? { |kw| skill_lower.include?(kw) }

    # DevOps & Tools
    devops_keywords = ['docker', 'kubernetes', 'aws', 'azure', 'gcp', 'git', 'github', 'ci/cd', 'jenkins', 'linux', 'bash', 'shell', 'deployment', 'infrastructure']
    return categories['DevOps & Tools'] if devops_keywords.any? { |kw| skill_lower.include?(kw) }

    # Business Strategy
    business_keywords = ['strategy', 'planning', 'business', 'market', 'competitive', 'swot', 'consulting', 'management', 'leadership', 'kpi', 'forecasting', 'financial']
    return categories['Business Strategy'] if business_keywords.any? { |kw| skill_lower.include?(kw) }

    # Marketing & Sales
    marketing_keywords = ['marketing', 'sales', 'advertising', 'campaign', 'social media', 'seo', 'sem', 'email marketing', 'content', 'branding', 'positioning', 'digital marketing']
    return categories['Marketing & Sales'] if marketing_keywords.any? { |kw| skill_lower.include?(kw) }

    # Communication & Soft Skills
    soft_keywords = ['communication', 'presentation', 'writing', 'speaking', 'teamwork', 'collaboration', 'problem solving', 'critical thinking', 'creativity', 'interviewing']
    return categories['Communication & Soft Skills'] if soft_keywords.any? { |kw| skill_lower.include?(kw) }

    # Project Management
    pm_keywords = ['project management', 'agile', 'scrum', 'kanban', 'waterfall', 'planning', 'coordination', 'stakeholder']
    return categories['Project Management'] if pm_keywords.any? { |kw| skill_lower.include?(kw) }

    # Research & Analysis
    research_keywords = ['research', 'survey', 'interviewing', 'qualitative', 'quantitative', 'primary research', 'secondary research']
    return categories['Research & Analysis'] if research_keywords.any? { |kw| skill_lower.include?(kw) }

    # Default to Other
    categories['Other']
  end

  def determine_skill_level(skill_name)
    skill_lower = skill_name.downcase

    return 'beginner' if ['basic', 'fundamental', 'intro', 'beginner'].any? { |word| skill_lower.include?(word) }
    return 'advanced' if ['advanced', 'expert', 'senior', 'lead'].any? { |word| skill_lower.include?(word) }

    'intermediate'
  end

  def extract_domain(skill_name)
    # Extract domain from skill name (simplified logic)
    skill_lower = skill_name.downcase

    return 'Technology' if ['programming', 'software', 'web', 'data', 'ai'].any? { |word| skill_lower.include?(word) }
    return 'Engineering' if ['engineering', 'mechanical', 'design'].any? { |word| skill_lower.include?(word) }
    return 'Business' if ['business', 'management', 'strategy', 'marketing'].any? { |word| skill_lower.include?(word) }

    'General'
  end

  def parse_date(date_string)
    return nil if date_string.blank?

    begin
      DateTime.parse(date_string)
    rescue
      Time.current
    end
  end

  def create_skill_relationships
    # Create relationships between related skills

    # Python ecosystem
    python_skills = Skill.where("name ILIKE ?", "%python%")
    data_science_skills = Skill.joins(:category).where(categories: { name: 'Data & Analytics' })

    python_skills.each do |python_skill|
      data_science_skills.each do |ds_skill|
        next if python_skill == ds_skill

        python_skill.add_related_skill(ds_skill, 'complementary')
      end
    end

    # CAD Software relationships
    cad_skills = Skill.where("name ILIKE ANY(ARRAY[?, ?, ?, ?])", "%solidworks%", "%autocad%", "%fusion%", "%inventor%")
    cad_skills.each do |skill1|
      cad_skills.each do |skill2|
        next if skill1 == skill2

        skill1.add_related_skill(skill2, 'alternative')
      end
    end

    puts "Created relationships for #{SkillRelationship.count} skill pairs"
  end
end
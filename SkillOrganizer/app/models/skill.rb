class Skill < ApplicationRecord
  belongs_to :category
  belongs_to :parent_skill, optional: true
  has_many :child_skills, class_name: 'Skill', foreign_key: 'parent_skill_id'

  has_many :skill_relationships, dependent: :destroy
  has_many :related_skills, through: :skill_relationships

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :skill_level, inclusion: { in: %w[beginner intermediate advanced] }

  scope :by_category, ->(category) { where(category: category) }
  scope :by_level, ->(level) { where(skill_level: level) }
  scope :search_by_name, ->(query) { where("name ILIKE ?", "%#{query}%") }
  scope :with_tags, ->(tags) { where("tags ?| array[:tags]", tags: Array(tags)) }

  before_save :normalize_name

  def self.skill_levels
    %w[beginner intermediate advanced]
  end

  def hierarchy_path
    return [self] if parent_skill.nil?
    parent_skill.hierarchy_path + [self]
  end

  def full_name
    hierarchy_path.map(&:name).join(' > ')
  end

  def add_related_skill(skill, relationship_type = 'related')
    skill_relationships.find_or_create_by(
      related_skill: skill,
      relationship_type: relationship_type
    )
  end

  private

  def normalize_name
    self.name = name.strip.titleize if name.present?
  end
end

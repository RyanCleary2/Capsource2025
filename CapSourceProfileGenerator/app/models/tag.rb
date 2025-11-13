class Tag < ApplicationRecord
  validates :category, :name, presence: true

  # Rich text fields
  has_rich_text :inspirations
  has_rich_text :description

  # Associations
  has_many :tag_resources, dependent: :destroy
  belongs_to :parent, foreign_key: :parent_id, class_name: 'Tag', optional: true
  has_many :children, foreign_key: :parent_id, class_name: 'Tag', dependent: :destroy

  # Comprehensive category enum matching CapSource
  enum :category, {
    topics: 0,
    industries: 1,
    company_sizes: 2,
    location_preferences: 3,
    student_levels: 4,
    workplace_preferences: 5,
    hiring_potentials: 6,
    domain_experts: 7,
    pdtopics: 8,
    skills: 9,
    education_majors: 10,
    educational_programs: 11,
    compensations: 12,
    student_location_preferences: 13,
    mentoring_location_preferences: 14
  }

  # Scopes
  scope :one_month, -> { where('created_at > ?', 30.days.ago) }
  scope :three_months, -> { where('created_at > ?', 90.days.ago) }
  scope :six_months, -> { where('created_at > ?', 180.days.ago) }
  scope :twelve_months, -> { where('created_at > ?', 365.days.ago) }

  # Find or create tag by name and category
  def self.find_or_create_skill(name)
    find_or_create_by(name: name.strip, category: :skills)
  end

  def self.find_or_create_industry(name)
    find_or_create_by(name: name.strip, category: :industries)
  end

  def self.find_or_create_topic(name)
    find_or_create_by(name: name.strip, category: :topics)
  end

  def self.find_or_create_domain_expert(name)
    find_or_create_by(name: name.strip, category: :domain_experts)
  end

  def self.find_or_create_pdtopic(name)
    find_or_create_by(name: name.strip, category: :pdtopics)
  end
end

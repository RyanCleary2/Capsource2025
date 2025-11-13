class Profile < ApplicationRecord
  belongs_to :user

  # Associations
  has_many :educational_backgrounds, dependent: :destroy
  has_many :professional_backgrounds, dependent: :destroy
  has_many :tag_resources, as: :resource, class_name: 'TagResource', dependent: :destroy

  # Tag associations through tag_resources (polymorphic)
  has_many :pdtopics, -> { where(tags: { category: 8 }) }, through: :tag_resources, source: :tag
  has_many :topics, -> { where(tags: { category: 0 }) }, through: :tag_resources, source: :tag
  has_many :domain_experts, -> { where(tags: { category: 7 }) }, through: :tag_resources, source: :tag
  has_many :industries, -> { where(tags: { category: 1 }) }, through: :tag_resources, source: :tag
  has_many :skills, -> { where(tags: { category: 9 }) }, through: :tag_resources, source: :tag

  # Rich text field for professional summary/about
  has_rich_text :about

  # Nested attributes
  accepts_nested_attributes_for :educational_backgrounds, allow_destroy: true
  accepts_nested_attributes_for :professional_backgrounds, allow_destroy: true

  # Enums matching CapSource
  enum :status, { draft: 0, completed: 1, published: 2 }
  enum :category, { mentor: 0, mentee: 1 }
  enum :builder_step, {
    profile_basics: 0,
    educational_background: 1,
    professional_background: 2,
    interests: 3,
    brief_biography: 4,
    professional_artifacts: 5,
    preview: 6,
    finished: 7
  }

  # Scopes
  scope :completed_or_published, -> { where(status: %i[completed published]) }
end

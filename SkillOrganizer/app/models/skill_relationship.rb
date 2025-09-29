class SkillRelationship < ApplicationRecord
  belongs_to :skill
  belongs_to :related_skill, class_name: 'Skill'

  validates :relationship_type, presence: true, inclusion: {
    in: %w[prerequisite successor related complementary alternative]
  }
  validates :skill_id, uniqueness: { scope: [:related_skill_id, :relationship_type] }

  scope :prerequisites, -> { where(relationship_type: 'prerequisite') }
  scope :successors, -> { where(relationship_type: 'successor') }
  scope :related, -> { where(relationship_type: 'related') }
  scope :complementary, -> { where(relationship_type: 'complementary') }
  scope :alternatives, -> { where(relationship_type: 'alternative') }

  def self.relationship_types
    %w[prerequisite successor related complementary alternative]
  end
end

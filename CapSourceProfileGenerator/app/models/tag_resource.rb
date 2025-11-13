class TagResource < ApplicationRecord
  belongs_to :tag
  belongs_to :resource, polymorphic: true

  validates :tag_id, uniqueness: { scope: [:resource_type, :resource_id] }

  # Optional: proficiency level for skills (e.g., for language proficiency)
  # This would require adding proficiency_level column to the table
  # enum proficiency_level: { beginner: 0, intermediate: 1, advanced: 2, expert: 3, native: 4 }
end

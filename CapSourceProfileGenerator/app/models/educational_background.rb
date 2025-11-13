class EducationalBackground < ApplicationRecord
  belongs_to :profile
  belongs_to :partner, optional: true

  # Validations are flexible to allow partial data during resume parsing
  # validates :university_college, :degree, :major, :graduation_year, presence: true
end

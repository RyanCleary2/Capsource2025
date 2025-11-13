class CompanyDetail < ApplicationRecord
  belongs_to :partner

  # Tag associations for hiring potentials
  has_many :tag_resources, as: :resource, class_name: 'TagResource', dependent: :destroy
  has_many :hiring_potentials, -> { where(tags: { category: 6 }) }, through: :tag_resources, source: :tag

  # Enums matching CapSource
  enum :growth_stage, {
    'Large Enterprise': 0,
    'Established Startup': 1,
    'Pre-Revenue Startup': 2,
    'Small Business': 3,
    'Medium Business': 4,
    'High-Growth Startup': 5
  }, prefix: true, scopes: false

  enum :employee_size, {
    'Unlisted': 0,
    '1-5': 1,
    '5-10': 2,
    '10-25': 3,
    '25-50': 4,
    '50-100': 5,
    '100-500': 6,
    '500-2500': 7,
    '2500+': 8
  }, prefix: true, scopes: false

  enum :global_status, {
    'Domestic': 0,
    'Global': 1,
    'International HQ': 2
  }, prefix: true, scopes: false

  enum :experiential_learning_experience, {
    'Beginner (Some experience)': 0,
    'No Experience': 1,
    'Intermediate (Have managed 1 to 4 projects)': 2,
    'Expert (4+ projects)': 3
  }, prefix: true, scopes: false

  enum :remote_collaboration_preferences, { 'Yes': 0, 'Maybe': 1, 'No': 2 }, prefix: true, scopes: false

  enum :student_seniority_preferences, {
    'All Undergraduate / All Graduate': 0,
    'All Graduate': 1,
    'All Undergraduate': 2,
    'Advanced Undergraduate / All Graduate': 3
  }, prefix: true, scopes: false

  enum :sponsor, { 'Yes': 0, 'Maybe': 1, 'No': 2 }, prefix: true, scopes: false
end

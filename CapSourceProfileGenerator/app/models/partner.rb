class Partner < ApplicationRecord
  # Associations
  has_one :company_detail, dependent: :destroy
  has_many :departments, dependent: :destroy
  has_many :partner_users, dependent: :destroy
  has_many :users, through: :partner_users
  has_many :educational_backgrounds
  has_many :professional_backgrounds

  # Tag associations (polymorphic)
  has_many :tag_resources, as: :resource, class_name: 'TagResource', dependent: :destroy
  has_many :topics, -> { where(tags: { category: 0 }) }, through: :tag_resources, source: :tag
  has_many :industries, -> { where(tags: { category: 1 }) }, through: :tag_resources, source: :tag
  has_many :pdtopics, -> { where(tags: { category: 8 }) }, through: :tag_resources, source: :tag
  has_many :domain_experts, -> { where(tags: { category: 7 }) }, through: :tag_resources, source: :tag
  has_many :skills, -> { where(tags: { category: 9 }) }, through: :tag_resources, source: :tag

  # Rich text fields for descriptions
  has_rich_text :short_description
  has_rich_text :long_description
  has_rich_text :overview
  has_rich_text :tagline

  # ActiveStorage attachments
  has_one_attached :logo
  has_one_attached :banner
  has_one_attached :promo_video

  # Nested attributes
  accepts_nested_attributes_for :company_detail
  accepts_nested_attributes_for :departments, allow_destroy: true
  accepts_nested_attributes_for :partner_users, allow_destroy: true

  # Delegate company detail fields
  delegate :employee_size, :experiential_learning_experience, :growth_stage, to: :company_detail, allow_nil: true

  # Enums matching CapSource
  enum :category, { company: 0, school: 1 }

  enum :organization_type, {
    'For Profit': 0,
    'Non Profit': 1,
    'Bcorp': 2,
    'Private For Profit': 3,
    'Public For Profit': 4,
    'Government Organization': 5,
    'Political Organization': 6,
    'Academic': 7
  }, prefix: true, scopes: false

  enum :employees_count, {
    '1-10': 0,
    '11-50': 1,
    '51-100': 2,
    '101-500': 3,
    '501-1000': 4,
    '1001-5000': 5,
    '5001-10000': 6,
    '10001-50000': 7,
    '50001+': 8
  }, prefix: true, scopes: false

  # Callbacks
  after_create_commit :create_company_detail_if_company

  private

  def create_company_detail_if_company
    return unless company?
    return if company_detail.present?

    CompanyDetail.create!(partner: self)
  end
end

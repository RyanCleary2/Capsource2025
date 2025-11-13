class User < ApplicationRecord
  # Devise modules for authentication (matching CapSource pattern)
  # devise :database_authenticatable, :registerable,
  #        :recoverable, :rememberable, :validatable

  # STI - Single Table Inheritance for different user types
  # Type can be: 'Users::Student', 'Users::Educator', 'Users::Company', 'Users::Admin'
  validates :type, presence: true

  # Serialize domain as JSON array for SQLite compatibility
  serialize :domain, coder: JSON

  # ActiveStorage attachment for profile picture
  has_one_attached :avatar

  # Associations
  has_one :profile, dependent: :destroy
  has_many :partner_users, dependent: :destroy
  has_many :partners, through: :partner_users

  # Nested attributes
  accepts_nested_attributes_for :profile

  # Scopes matching CapSource patterns
  scope :students, -> { where(type: 'Users::Student') }
  scope :educators, -> { where(type: 'Users::Educator') }
  scope :companies, -> { where(type: 'Users::Company') }
  scope :admins, -> { where(type: 'Users::Admin') }

  # Callbacks
  after_create_commit :create_profile, unless: -> { profile.present? }

  # Type checking methods
  def student?
    type == 'Users::Student'
  end

  def company?
    type == 'Users::Company'
  end

  def educator?
    type == 'Users::Educator'
  end

  def admin?
    type == 'Users::Admin'
  end

  private

  def create_profile
    Profile.create!(user: self)
  end
end

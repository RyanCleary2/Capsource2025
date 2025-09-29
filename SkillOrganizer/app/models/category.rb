class Category < ApplicationRecord
  belongs_to :parent_category, optional: true
  has_many :child_categories, class_name: 'Category', foreign_key: 'parent_category_id'
  has_many :skills, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :parent_category_id }

  scope :root_categories, -> { where(parent_category: nil) }

  def hierarchy_path
    return [self] if parent_category.nil?
    parent_category.hierarchy_path + [self]
  end

  def full_name
    hierarchy_path.map(&:name).join(' > ')
  end
end

class Department < ApplicationRecord
  belongs_to :partner

  validates :name, presence: true
end

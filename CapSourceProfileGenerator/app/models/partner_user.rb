class PartnerUser < ApplicationRecord
  belongs_to :partner
  belongs_to :user

  validates :user_id, uniqueness: { scope: :partner_id }
end

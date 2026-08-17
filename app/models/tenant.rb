class Tenant < ApplicationRecord
  has_secure_token :api_key

  has_many :feedbacks, dependent: :destroy
  has_one :aggregate, class_name: "TenantAggregate", dependent: :destroy

  validates :name, presence: true
end

class Tenant < ApplicationRecord
  has_secure_token :api_key

  has_many :feedbacks, dependent: :destroy
  has_many :daily_stats, class_name: "TenantDailyStat", dependent: :destroy

  validates :name, presence: true
end

class Feedback < ApplicationRecord
  STATUSES = %w[pending sentiment_analyzed aggregated].freeze
  WEBHOOK_STATUSES = %w[pending sent failed].freeze
  SENTIMENTS = %w[positive negative neutral].freeze

  belongs_to :tenant
  has_many :outbox_events, dependent: :destroy

  validates :external_id, presence: true, uniqueness: { scope: :tenant_id }
  validates :customer_id, presence: true
  validates :score, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }
  validates :webhook_status, inclusion: { in: WEBHOOK_STATUSES }
  validates :sentiment, inclusion: { in: SENTIMENTS }, allow_nil: true
end

class OutboxEvent < ApplicationRecord
  STATUSES = %w[pending enqueuing enqueued].freeze
  ENQUEUE_LOCK_TTL = 5.minutes

  belongs_to :tenant
  belongs_to :feedback

  validates :event_type, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :retryable, -> {
    where(status: "pending")
      .or(where(status: "enqueuing").where("lock_expires_at <= ?", Time.current))
  }

  def enqueue!
    claimed = self.class
      .where(id: id)
      .where("status = ? OR (status = ? AND lock_expires_at <= ?)", "pending", "enqueuing", Time.current)
      .update_all(status: "enqueuing", lock_expires_at: ENQUEUE_LOCK_TTL.from_now)

    return unless claimed.positive?

    SentimentJob.perform_async(feedback_id)
    update_columns(status: "enqueued", processed_at: Time.current, lock_expires_at: nil)
  rescue StandardError => e
    AppLogger.error("outbox_event.enqueue_failed", outbox_event_id: id, error: e.class.name)
    update_columns(status: "pending", lock_expires_at: nil)
  end
end

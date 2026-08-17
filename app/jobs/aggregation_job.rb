class AggregationJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 5

  def perform(feedback_id)
    feedback = Feedback.find(feedback_id)

    claimed = Feedback.transaction do
      rows = Feedback.where(id: feedback.id, status: "sentiment_analyzed")
                      .update_all(status: "aggregated", updated_at: Time.current)
      TenantDailyStat.increment_for!(feedback) if rows.positive?
      rows
    end

    AppLogger.info("aggregation_job.completed", feedback_id: feedback.id, incremented: claimed.positive?)
    WebhookJob.perform_async(feedback.id)
  rescue ActiveRecord::RecordNotFound
    AppLogger.warn("aggregation_job.feedback_not_found", feedback_id: feedback_id)
  end
end

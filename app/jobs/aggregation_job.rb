class AggregationJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 5

  def perform(feedback_id)
    feedback = Feedback.find(feedback_id)

    claimed = Feedback.where(id: feedback.id, status: "sentiment_analyzed")
                       .update_all(status: "aggregated", updated_at: Time.current)
    increment_aggregate(feedback) if claimed.positive?

    AppLogger.info("aggregation_job.completed", feedback_id: feedback.id, incremented: claimed.positive?)
    WebhookJob.perform_async(feedback.id)
  rescue ActiveRecord::RecordNotFound
    AppLogger.warn("aggregation_job.feedback_not_found", feedback_id: feedback_id)
  end

  private

  def increment_aggregate(feedback)
    column = TenantAggregate::SENTIMENT_COLUMNS[feedback.sentiment]
    unless column
      AppLogger.warn("aggregation_job.unknown_sentiment", feedback_id: feedback.id, sentiment: feedback.sentiment)
      return
    end

    aggregate = TenantAggregate.create_or_find_by!(tenant_id: feedback.tenant_id)
    TenantAggregate.update_counters(aggregate.id, column.to_sym => 1)
  end
end

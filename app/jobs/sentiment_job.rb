class SentimentJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 5

  def perform(feedback_id)
    feedback = Feedback.find(feedback_id)
    sentiment = SentimentAnalyzer.call(feedback)

    Feedback.where(id: feedback.id, status: "pending")
            .update_all(sentiment: sentiment, status: "sentiment_analyzed", updated_at: Time.current)

    AppLogger.info("sentiment_job.completed", feedback_id: feedback.id, sentiment: sentiment)
    AggregationJob.perform_async(feedback.id)
  rescue ActiveRecord::RecordNotFound
    AppLogger.warn("sentiment_job.feedback_not_found", feedback_id: feedback_id)
  end
end

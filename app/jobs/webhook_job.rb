class WebhookJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 5

  class DeliveryError < StandardError; end

  def perform(feedback_id)
    feedback = Feedback.find(feedback_id)
    return if feedback.webhook_status == "sent"

    response = WebhookClient.new.post(payload: payload_for(feedback), idempotency_key: "feedback-#{feedback.id}")

    if response.success?
      feedback.update!(webhook_status: "sent", webhook_sent_at: Time.current)
      AppLogger.info("webhook_job.delivered", feedback_id: feedback.id)
    else
      feedback.update!(webhook_status: "failed")
      AppLogger.error("webhook_job.failed", feedback_id: feedback.id, code: response.code)
      raise DeliveryError, "webhook delivery failed for feedback_id=#{feedback.id} code=#{response.code}"
    end
  rescue ActiveRecord::RecordNotFound
    AppLogger.warn("webhook_job.feedback_not_found", feedback_id: feedback_id)
  end

  private

  def payload_for(feedback)
    {
      tenant_id: feedback.tenant_id,
      feedback_id: feedback.id,
      external_id: feedback.external_id,
      sentiment: feedback.sentiment,
      status: feedback.status
    }
  end
end

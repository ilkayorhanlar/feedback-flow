module Feedbacks
  class IngestService
    class Result
      attr_reader :feedback, :errors

      def initialize(feedback: nil, errors: nil, already_exists: false)
        @feedback = feedback
        @errors = errors
        @already_exists = already_exists
      end

      def success?
        errors.blank?
      end

      def already_exists?
        @already_exists
      end
    end

    MAX_UNIQUENESS_RETRIES = 1

    def self.call(...)
      new(...).call
    end

    def initialize(tenant:, params:)
      @tenant = tenant
      @params = params
    end

    def call
      attempt ||= 0

      if (existing = find_existing_feedback)
        AppLogger.info("feedback.duplicate_request", tenant_id: tenant.id, external_id: params[:external_id])
        return Result.new(feedback: existing, already_exists: true)
      end

      feedback = build_feedback
      return Result.new(errors: feedback.errors.to_hash(full_messages: true)) unless feedback.valid?

      persist(feedback)
    rescue ActiveRecord::RecordNotUnique
      attempt += 1
      retry if attempt <= MAX_UNIQUENESS_RETRIES
      raise
    end

    private

    attr_reader :tenant, :params

    def find_existing_feedback
      tenant.feedbacks.find_by(external_id: params[:external_id])
    end

    def build_feedback
      tenant.feedbacks.new(
        external_id: params[:external_id],
        survey_id: params[:survey_id],
        customer_id: params[:customer_id],
        score: params[:score],
        comment: params[:comment],
        occurred_at: params[:occurred_at]
      )
    end

    def persist(feedback)
      outbox_event = nil

      ActiveRecord::Base.transaction do
        feedback.save!
        outbox_event = OutboxEvent.create!(tenant: tenant, feedback: feedback, event_type: "feedback_created")
      end

      AppLogger.info("feedback.created", tenant_id: tenant.id, feedback_id: feedback.id, customer_id: feedback.customer_id)

      outbox_event.enqueue!

      Result.new(feedback: feedback, already_exists: false)
    end
  end
end

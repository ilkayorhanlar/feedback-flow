class Api::V1::FeedbacksController < ApplicationController
  def create
    result = Feedbacks::IngestService.call(tenant: Current.tenant, params: feedback_params)

    if result.success?
      render json: serialize(result.feedback), status: result.already_exists? ? :ok : :created
    else
      render json: { errors: result.errors }, status: :unprocessable_content
    end
  end

  private

  def feedback_params
    params.permit(:external_id, :survey_id, :customer_id, :score, :comment, :occurred_at)
  end

  def serialize(feedback)
    {
      id: feedback.id,
      external_id: feedback.external_id,
      status: feedback.status,
      sentiment: feedback.sentiment,
      customer_id: feedback.customer_id,
      created_at: feedback.created_at
    }
  end
end

require "rails_helper"

RSpec.describe Feedbacks::IngestService do
  let(:tenant) { create_tenant }

  def params(overrides = {})
    {
      external_id: "feedback-123",
      survey_id: 421,
      customer_id: "customer-456",
      score: 5,
      comment: "Great service",
      occurred_at: "2026-08-11T10:22:00Z"
    }.merge(overrides)
  end

  it "creates a feedback inside a transaction" do
    result = described_class.call(tenant: tenant, params: params)

    expect(result).to be_success
    expect(result.already_exists?).to be false
    expect(result.feedback).to be_persisted
    expect(result.feedback.customer_id).to eq("customer-456")
  end

  it "writes an outbox event for the created feedback" do
    result = described_class.call(tenant: tenant, params: params)

    expect(OutboxEvent.find_by(feedback: result.feedback)).to be_present
  end

  it "is idempotent for a repeated external_id within the same tenant" do
    first = described_class.call(tenant: tenant, params: params)
    second = described_class.call(tenant: tenant, params: params)

    expect(second.already_exists?).to be true
    expect(second.feedback.id).to eq(first.feedback.id)
    expect(Feedback.where(tenant: tenant, external_id: "feedback-123").count).to eq(1)
  end

  it "returns field errors for invalid input without touching the DB" do
    result = described_class.call(tenant: tenant, params: params(score: 99))

    expect(result).not_to be_success
    expect(result.errors).to be_present
    expect(Feedback.where(tenant: tenant).count).to eq(0)
  end

  it "requires a customer_id" do
    result = described_class.call(tenant: tenant, params: params(customer_id: nil))

    expect(result).not_to be_success
    expect(result.errors[:customer_id]).to be_present
  end

  it "does not create a duplicate feedback if two requests race past the existence check" do
    winner = described_class.call(tenant: tenant, params: params)
    expect(winner).to be_success

    service = described_class.new(tenant: tenant, params: params)
    allow(service).to receive(:find_existing_feedback).and_return(nil, winner.feedback)
    allow_any_instance_of(Feedback).to receive(:valid?).and_return(true)

    result = service.call

    expect(result).to be_success
    expect(result.already_exists?).to be true
    expect(result.feedback.id).to eq(winner.feedback.id)
    expect(Feedback.where(tenant: tenant, external_id: "feedback-123").count).to eq(1)
  end
end

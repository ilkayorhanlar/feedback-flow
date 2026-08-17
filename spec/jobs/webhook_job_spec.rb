require "rails_helper"

RSpec.describe WebhookJob do
  let(:tenant) { create_tenant }
  let(:feedback) { create_feedback(tenant, score: 5, sentiment: "positive", status: "aggregated") }
  let(:endpoint) { Rails.application.config.x.webhook.endpoint }

  it "delivers the webhook and marks the feedback as sent" do
    stub = stub_request(:post, endpoint).to_return(status: 200, body: "ok")

    described_class.new.perform(feedback.id)

    expect(stub).to have_been_requested
    expect(feedback.reload.webhook_status).to eq("sent")
    expect(feedback.webhook_sent_at).to be_present
  end

  it "sends an Idempotency-Key header" do
    stub_request(:post, endpoint).to_return(status: 200)

    described_class.new.perform(feedback.id)

    expect(WebMock).to have_requested(:post, endpoint).with(headers: { "Idempotency-Key" => "feedback-#{feedback.id}" })
  end

  it "marks the feedback failed and raises to trigger a Sidekiq retry when delivery fails" do
    stub_request(:post, endpoint).to_return(status: 500, body: "error")

    expect { described_class.new.perform(feedback.id) }.to raise_error(WebhookJob::DeliveryError)
    expect(feedback.reload.webhook_status).to eq("failed")
  end

  it "does not send a second request once the webhook was already sent (duplicate execution)" do
    stub = stub_request(:post, endpoint).to_return(status: 200)

    described_class.new.perform(feedback.id)
    described_class.new.perform(feedback.id)

    expect(stub).to have_been_requested.times(1)
  end

  it "retries (resends) after a prior failed attempt" do
    stub_request(:post, endpoint).to_return({ status: 500 }, { status: 200 })

    expect { described_class.new.perform(feedback.id) }.to raise_error(WebhookJob::DeliveryError)
    expect(feedback.reload.webhook_status).to eq("failed")

    described_class.new.perform(feedback.id)
    expect(feedback.reload.webhook_status).to eq("sent")
  end

  it "does not raise when the feedback no longer exists" do
    missing_id = feedback.id
    feedback.destroy

    expect { described_class.new.perform(missing_id) }.not_to raise_error
  end
end

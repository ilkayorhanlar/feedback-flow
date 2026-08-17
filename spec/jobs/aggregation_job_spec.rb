require "rails_helper"

RSpec.describe AggregationJob do
  let(:tenant) { create_tenant }
  let(:feedback) { create_feedback(tenant, score: 5, sentiment: "positive", status: "sentiment_analyzed") }

  it "increments the tenant's positive_count" do
    described_class.new.perform(feedback.id)

    aggregate = TenantAggregate.find_by(tenant: tenant)
    expect(aggregate.positive_count).to eq(1)
    expect(aggregate.negative_count).to eq(0)
  end

  it "transitions the feedback status to aggregated" do
    described_class.new.perform(feedback.id)

    expect(feedback.reload.status).to eq("aggregated")
  end

  it "enqueues WebhookJob" do
    expect {
      described_class.new.perform(feedback.id)
    }.to change { WebhookJob.jobs.size }.by(1)
  end

  it "does not double-count when run twice for the same feedback (duplicate execution)" do
    described_class.new.perform(feedback.id)
    described_class.new.perform(feedback.id)

    aggregate = TenantAggregate.find_by(tenant: tenant)
    expect(aggregate.positive_count).to eq(1)
  end

  it "still forwards to WebhookJob on the second (no-op) run" do
    described_class.new.perform(feedback.id)
    expect {
      described_class.new.perform(feedback.id)
    }.to change { WebhookJob.jobs.size }.by(1)
  end

  it "correctly separates counts per tenant" do
    other_tenant = create_tenant
    other_feedback = create_feedback(other_tenant, score: 1, sentiment: "negative", status: "sentiment_analyzed")

    described_class.new.perform(feedback.id)
    described_class.new.perform(other_feedback.id)

    expect(TenantAggregate.find_by(tenant: tenant).positive_count).to eq(1)
    expect(TenantAggregate.find_by(tenant: other_tenant).negative_count).to eq(1)
  end

  it "does not raise when the feedback no longer exists" do
    missing_id = feedback.id
    feedback.destroy

    expect { described_class.new.perform(missing_id) }.not_to raise_error
  end
end

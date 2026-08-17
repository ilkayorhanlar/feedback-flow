require "rails_helper"

RSpec.describe AggregationJob do
  let(:tenant) { create_tenant }
  let(:feedback) { create_feedback(tenant, score: 5, sentiment: "positive", status: "sentiment_analyzed") }

  def stat_for(feedback)
    TenantDailyStat.find_by(tenant: feedback.tenant, stat_date: feedback.occurred_at&.to_date || feedback.created_at.to_date)
  end

  it "records the feedback in tenant_daily_stats for its occurred_at date" do
    described_class.new.perform(feedback.id)

    stat = stat_for(feedback)
    expect(stat.feedback_count).to eq(1)
    expect(stat.score_sum).to eq(5)
    expect(stat.score_count).to eq(1)
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

  it "does not double-count tenant_daily_stats when run twice for the same feedback (duplicate execution)" do
    described_class.new.perform(feedback.id)
    described_class.new.perform(feedback.id)

    expect(stat_for(feedback).feedback_count).to eq(1)
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

    expect(stat_for(feedback).feedback_count).to eq(1)
    expect(stat_for(other_feedback).feedback_count).to eq(1)
  end

  it "does not raise when the feedback no longer exists" do
    missing_id = feedback.id
    feedback.destroy

    expect { described_class.new.perform(missing_id) }.not_to raise_error
  end
end

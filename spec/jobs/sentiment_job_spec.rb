require "rails_helper"

RSpec.describe SentimentJob do
  let(:tenant) { create_tenant }
  let(:feedback) { create_feedback(tenant, score: 5) }

  it "computes and persists the sentiment" do
    described_class.new.perform(feedback.id)

    expect(feedback.reload.sentiment).to eq("positive")
    expect(feedback.status).to eq("sentiment_analyzed")
  end

  it "enqueues AggregationJob" do
    expect {
      described_class.new.perform(feedback.id)
    }.to change { AggregationJob.jobs.size }.by(1)
    expect(AggregationJob.jobs.last["args"]).to eq([feedback.id])
  end

  it "does not raise when the feedback no longer exists (e.g. deleted before the job ran)" do
    missing_id = feedback.id
    feedback.destroy

    expect { described_class.new.perform(missing_id) }.not_to raise_error
  end

  it "is idempotent under duplicate execution" do
    described_class.new.perform(feedback.id)
    expect {
      described_class.new.perform(feedback.id)
    }.not_to change { feedback.reload.sentiment }

    expect(AggregationJob.jobs.size).to eq(2)
  end

  it "retries on unexpected failure" do
    allow(SentimentAnalyzer).to receive(:call).and_raise(StandardError, "boom")

    expect { described_class.new.perform(feedback.id) }.to raise_error(StandardError, "boom")
    expect(feedback.reload.status).to eq("pending")
    expect(AggregationJob.jobs).to be_empty
  end
end

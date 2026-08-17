require "rails_helper"

RSpec.describe OutboxEvent, type: :model do
  let(:tenant) { create_tenant }
  let(:feedback) { create_feedback(tenant) }

  it "enqueues SentimentJob and transitions to enqueued" do
    event = OutboxEvent.create!(tenant: tenant, feedback: feedback, event_type: "feedback_created")

    expect { event.enqueue! }.to change { SentimentJob.jobs.size }.by(1)
    expect(event.reload.status).to eq("enqueued")
    expect(SentimentJob.jobs.last["args"]).to eq([feedback.id])
  end

  it "is a no-op when called twice (idempotent processing)" do
    event = OutboxEvent.create!(tenant: tenant, feedback: feedback, event_type: "feedback_created")

    event.enqueue!
    expect { event.enqueue! }.not_to change { SentimentJob.jobs.size }
  end

  it "leaves the event pending for the sweeper if enqueueing raises" do
    event = OutboxEvent.create!(tenant: tenant, feedback: feedback, event_type: "feedback_created")
    allow(SentimentJob).to receive(:perform_async).and_raise(StandardError, "redis down")

    event.enqueue!

    expect(event.reload.status).to eq("pending")
  end

  it "reclaims a stale enqueuing event so the sweeper can retry it" do
    event = OutboxEvent.create!(
      tenant: tenant,
      feedback: feedback,
      event_type: "feedback_created",
      status: "enqueuing",
      lock_expires_at: 5.minutes.ago
    )

    expect { event.enqueue! }.to change { SentimentJob.jobs.size }.by(1)
    expect(event.reload.status).to eq("enqueued")
  end
end

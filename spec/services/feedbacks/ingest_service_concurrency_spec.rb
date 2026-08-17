require "rails_helper"

RSpec.describe Feedbacks::IngestService, type: :model do
  self.use_transactional_tests = false

  it "creates exactly one feedback when two requests race concurrently" do
    tenant = create_tenant

    params = {
      external_id: "feedback-race",
      survey_id: 421,
      customer_id: "customer-race",
      score: 5,
      comment: "Great service",
      occurred_at: "2026-08-11T10:22:00Z"
    }

    results = Queue.new

    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          results << described_class.call(tenant: tenant, params: params)
        end
      end
    end
    threads.each(&:join)

    outcomes = Array.new(2) { results.pop }

    expect(outcomes).to all(be_success)
    expect(outcomes.map { |r| r.feedback.id }.uniq.size).to eq(1)
    expect(Feedback.where(tenant: tenant, external_id: "feedback-race").count).to eq(1)
  ensure
    OutboxEvent.where(tenant: tenant).delete_all
    Feedback.where(tenant: tenant).delete_all
    tenant&.destroy
  end
end

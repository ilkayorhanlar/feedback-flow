require "rails_helper"

RSpec.describe TenantDailyStat, type: :model do
  let(:tenant) { create_tenant }

  describe ".increment_for!" do
    it "creates a row for the tenant and date on first call" do
      feedback = create_feedback(tenant, score: 4, occurred_at: Time.zone.parse("2026-08-10 10:00:00"))

      described_class.increment_for!(feedback)
      stat = described_class.find_by(tenant: tenant, stat_date: Date.new(2026, 8, 10))

      expect(stat.feedback_count).to eq(1)
      expect(stat.score_sum).to eq(4)
      expect(stat.score_count).to eq(1)
    end

    it "accumulates counts across multiple calls for the same tenant and date" do
      feedback_a = create_feedback(tenant, score: 4, occurred_at: Time.zone.parse("2026-08-10 09:00:00"))
      feedback_b = create_feedback(tenant, score: 2, occurred_at: Time.zone.parse("2026-08-10 18:00:00"))

      described_class.increment_for!(feedback_a)
      described_class.increment_for!(feedback_b)
      stat = described_class.find_by(tenant: tenant, stat_date: Date.new(2026, 8, 10))

      expect(stat.feedback_count).to eq(2)
      expect(stat.score_sum).to eq(6)
      expect(stat.score_count).to eq(2)
    end

    it "keeps separate rows per day" do
      feedback_day_1 = create_feedback(tenant, score: 5, occurred_at: Time.zone.parse("2026-08-10 10:00:00"))
      feedback_day_2 = create_feedback(tenant, score: 1, occurred_at: Time.zone.parse("2026-08-11 10:00:00"))

      described_class.increment_for!(feedback_day_1)
      described_class.increment_for!(feedback_day_2)

      expect(described_class.where(tenant: tenant).count).to eq(2)
    end

    it "falls back to created_at when occurred_at is nil" do
      feedback = create_feedback(tenant, score: 3, occurred_at: nil)

      described_class.increment_for!(feedback)
      stat = described_class.find_by(tenant: tenant, stat_date: feedback.created_at.to_date)

      expect(stat.feedback_count).to eq(1)
    end

    it "counts feedback without a score toward feedback_count but not score_count" do
      feedback = create_feedback(tenant, score: nil, occurred_at: Time.zone.parse("2026-08-10 10:00:00"))

      described_class.increment_for!(feedback)
      stat = described_class.find_by(tenant: tenant, stat_date: Date.new(2026, 8, 10))

      expect(stat.feedback_count).to eq(1)
      expect(stat.score_sum).to eq(0)
      expect(stat.score_count).to eq(0)
    end
  end

  describe "#avg_score" do
    it "divides score_sum by score_count" do
      stat = described_class.new(score_sum: 9, score_count: 3)

      expect(stat.avg_score).to eq(3.0)
    end

    it "returns nil when no scored feedback has been recorded" do
      stat = described_class.new(score_sum: 0, score_count: 0)

      expect(stat.avg_score).to be_nil
    end
  end

  describe "constraints" do
    it "enforces uniqueness on tenant_id and stat_date" do
      described_class.create!(tenant: tenant, stat_date: Date.new(2026, 8, 10), feedback_count: 1)

      expect {
        described_class.create!(tenant: tenant, stat_date: Date.new(2026, 8, 10), feedback_count: 1)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects a negative feedback_count at the database level" do
      stat = described_class.new(tenant: tenant, stat_date: Date.current, feedback_count: -1)

      expect { stat.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end

require "rails_helper"

RSpec.describe SentimentAnalyzer do
  let(:tenant) { create_tenant }

  def feedback_with(score: nil, comment: nil)
    tenant.feedbacks.new(external_id: "f-1", customer_id: "customer-1", score: score, comment: comment)
  end

  it "is positive for high scores" do
    expect(described_class.call(feedback_with(score: 5))).to eq("positive")
  end

  it "is negative for low scores" do
    expect(described_class.call(feedback_with(score: 1))).to eq("negative")
  end

  it "is neutral for mid-range scores" do
    expect(described_class.call(feedback_with(score: 3))).to eq("neutral")
  end

  it "falls back to comment keywords when there is no score" do
    expect(described_class.call(feedback_with(comment: "This was an amazing and great experience"))).to eq("positive")
    expect(described_class.call(feedback_with(comment: "Terrible and awful, I hate it"))).to eq("negative")
  end

  it "is neutral when there is neither score nor comment" do
    expect(described_class.call(feedback_with)).to eq("neutral")
  end

  it "is deterministic" do
    feedback = feedback_with(score: 5)
    expect(described_class.call(feedback)).to eq(described_class.call(feedback))
  end
end

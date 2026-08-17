require "rails_helper"

RSpec.describe Feedback, type: :model do
  let(:tenant) { create_tenant }

  it "requires an external_id" do
    feedback = tenant.feedbacks.new(customer_id: "customer-1")
    expect(feedback).not_to be_valid
    expect(feedback.errors[:external_id]).to be_present
  end

  it "requires a customer_id" do
    feedback = tenant.feedbacks.new(external_id: "f-1", score: 5)
    expect(feedback).not_to be_valid
    expect(feedback.errors[:customer_id]).to be_present
  end

  it "rejects a score outside 1..5" do
    feedback = tenant.feedbacks.new(external_id: "f-1", customer_id: "customer-1", score: 6)
    expect(feedback).not_to be_valid
    expect(feedback.errors[:score]).to be_present
  end

  it "enforces external_id uniqueness scoped to tenant at the DB level" do
    create_feedback(tenant, customer_id: "customer-1", external_id: "dup")
    duplicate = tenant.feedbacks.new(external_id: "dup", customer_id: "customer-1", score: 5)

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows the same external_id across different tenants" do
    other_tenant = create_tenant
    create_feedback(tenant, customer_id: "customer-1", external_id: "shared")

    expect { create_feedback(other_tenant, customer_id: "customer-1", external_id: "shared") }.not_to raise_error
  end
end

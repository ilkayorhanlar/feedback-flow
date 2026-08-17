module TenantHelpers
  def create_tenant(name: "Tenant #{SecureRandom.hex(4)}")
    Tenant.create!(name: name)
  end

  def create_feedback(tenant, customer_id: "customer-#{SecureRandom.hex(4)}", external_id: "feedback-#{SecureRandom.hex(4)}", **attrs)
    tenant.feedbacks.create!(external_id: external_id, customer_id: customer_id, score: 5, **attrs)
  end
end

RSpec.configure do |config|
  config.include TenantHelpers
end

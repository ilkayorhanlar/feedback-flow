require "rails_helper"

RSpec.describe Tenant, type: :model do
  it "requires a name" do
    tenant = Tenant.new
    expect(tenant).not_to be_valid
    expect(tenant.errors[:name]).to be_present
  end

  it "generates a unique api_key on creation" do
    tenant = create_tenant

    expect(tenant.api_key).to be_present
  end

  it "does not allow two tenants to share an api_key" do
    tenant = create_tenant
    other = Tenant.new(name: "Other")
    other.api_key = tenant.api_key

    expect { other.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end

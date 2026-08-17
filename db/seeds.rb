# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

demo_tenant = Tenant.find_or_create_by!(name: "Demo Tenant")

puts "Demo tenant ready: id=#{demo_tenant.id} api_key=#{demo_tenant.api_key}"
puts "Try it:"
puts <<~CURL
  curl -X POST http://localhost:3000/api/v1/feedbacks \\
    -H "Content-Type: application/json" \\
    -H "X-Api-Key: #{demo_tenant.api_key}" \\
    -d '{"external_id":"feedback-123","survey_id":421,"customer_id":"customer-456","score":5,"comment":"Great service","occurred_at":"2026-08-11T10:22:00Z"}'
CURL

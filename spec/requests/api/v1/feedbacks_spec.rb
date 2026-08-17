require "rails_helper"

RSpec.describe "Api::V1::Feedbacks", type: :request do
  let(:tenant) { create_tenant }
  let(:headers) { { "X-Api-Key" => tenant.api_key, "CONTENT_TYPE" => "application/json" } }

  def valid_payload(overrides = {})
    {
      external_id: "feedback-123",
      survey_id: 421,
      customer_id: "customer-456",
      score: 5,
      comment: "Great service",
      occurred_at: "2026-08-11T10:22:00Z"
    }.merge(overrides)
  end

  describe "POST /api/v1/feedbacks" do
    context "without an API key" do
      it "returns 401" do
        post "/api/v1/feedbacks", params: valid_payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a valid request" do
      it "creates the feedback and returns 201" do
        expect {
          post "/api/v1/feedbacks", params: valid_payload.to_json, headers: headers
        }.to change(Feedback, :count).by(1)

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["external_id"]).to eq("feedback-123")
        expect(body["status"]).to eq("pending")
        expect(body["customer_id"]).to eq("customer-456")
      end

      it "scopes the created records to the authenticated tenant" do
        post "/api/v1/feedbacks", params: valid_payload.to_json, headers: headers

        feedback = Feedback.find(response.parsed_body["id"])
        expect(feedback.tenant_id).to eq(tenant.id)
      end

      it "enqueues the pipeline via the outbox" do
        expect {
          post "/api/v1/feedbacks", params: valid_payload.to_json, headers: headers
        }.to change { SentimentJob.jobs.size }.by(1)
      end
    end

    context "with an invalid request" do
      it "returns 422 with field errors when external_id is missing" do
        post "/api/v1/feedbacks", params: valid_payload(external_id: nil).to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "returns 422 when customer_id is missing" do
        post "/api/v1/feedbacks", params: valid_payload(customer_id: nil).to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]["customer_id"]).to be_present
      end

      it "returns 422 when score is out of range" do
        post "/api/v1/feedbacks", params: valid_payload(score: 42).to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "does not create any records on validation failure" do
        expect {
          post "/api/v1/feedbacks", params: valid_payload(external_id: nil).to_json, headers: headers
        }.not_to change(Feedback, :count)
      end
    end

    context "duplicate requests (idempotency)" do
      it "does not create a second feedback for the same tenant + external_id" do
        post "/api/v1/feedbacks", params: valid_payload.to_json, headers: headers
        expect(response).to have_http_status(:created)

        expect {
          post "/api/v1/feedbacks", params: valid_payload.to_json, headers: headers
        }.not_to change(Feedback, :count)

        expect(response).to have_http_status(:ok)
      end

      it "allows the same external_id for a different tenant" do
        post "/api/v1/feedbacks", params: valid_payload.to_json, headers: headers
        expect(response).to have_http_status(:created)

        other_tenant = create_tenant
        other_headers = { "X-Api-Key" => other_tenant.api_key, "CONTENT_TYPE" => "application/json" }

        expect {
          post "/api/v1/feedbacks", params: valid_payload.to_json, headers: other_headers
        }.to change(Feedback, :count).by(1)

        expect(response).to have_http_status(:created)
      end
    end

    context "tenant isolation" do
      it "never exposes another tenant's data through this tenant's requests" do
        other_tenant = create_tenant
        create_feedback(other_tenant, customer_id: "customer-456", external_id: "feedback-123")

        expect {
          post "/api/v1/feedbacks", params: valid_payload.to_json, headers: headers
        }.to change(Feedback, :count).by(1)

        expect(response).to have_http_status(:created)
        created = Feedback.find(response.parsed_body["id"])
        expect(created.tenant_id).to eq(tenant.id)
        expect(created.id).not_to eq(Feedback.find_by(tenant_id: other_tenant.id, external_id: "feedback-123").id)
      end
    end
  end
end

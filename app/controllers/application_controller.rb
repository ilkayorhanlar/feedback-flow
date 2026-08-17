class ApplicationController < ActionController::API
  before_action :authenticate_tenant!

  rescue_from ActionController::ParameterMissing do |e|
    render json: { errors: { base: [e.message] } }, status: :bad_request
  end

  private

  def authenticate_tenant!
    api_key = request.headers["X-Api-Key"]
    tenant = api_key.present? ? Tenant.find_by(api_key: api_key) : nil

    if tenant.nil?
      render json: { errors: { base: ["invalid or missing API key"] } }, status: :unauthorized
      return
    end

    Current.tenant = tenant
  end
end

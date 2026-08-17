require "net/http"
require "uri"

class WebhookClient
  Response = Struct.new(:success, :code, :body, keyword_init: true) do
    def success?
      success
    end
  end

  def initialize(endpoint: Rails.application.config.x.webhook.endpoint,
                  open_timeout: 2, read_timeout: 5)
    @endpoint = endpoint
    @open_timeout = open_timeout
    @read_timeout = read_timeout
  end

  def post(payload:, idempotency_key:)
    uri = URI.parse(endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = open_timeout
    http.read_timeout = read_timeout

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["Idempotency-Key"] = idempotency_key
    request.body = payload.to_json

    response = http.request(request)
    Response.new(success: response.is_a?(Net::HTTPSuccess), code: response.code, body: response.body)
  rescue Timeout::Error, SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
    AppLogger.error("webhook_client.network_error", error: e.class.name)
    Response.new(success: false, code: nil, body: nil)
  end

  private

  attr_reader :endpoint, :open_timeout, :read_timeout
end

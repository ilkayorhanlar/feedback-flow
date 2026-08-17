Rails.application.config.x.webhook.endpoint = ENV.fetch("WEBHOOK_URL", "http://localhost:9999/webhooks/feedback")

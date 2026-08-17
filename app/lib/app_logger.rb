module AppLogger
  class << self
    def info(event, **data)
      Rails.logger.info(build(event, data))
    end

    def warn(event, **data)
      Rails.logger.warn(build(event, data))
    end

    def error(event, **data)
      Rails.logger.error(build(event, data))
    end

    private

    def build(event, data)
      { event: event, **data }.to_json
    end
  end
end

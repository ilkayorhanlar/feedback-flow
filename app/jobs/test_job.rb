class TestJob
  include Sidekiq::Job

  def perform
    Rails.logger.info "Test job running at #{Time.current}"
  end
end
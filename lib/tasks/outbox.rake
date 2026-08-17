namespace :outbox do
  desc "Enqueue Sidekiq jobs for any outbox events still pending or whose enqueue lock expired"
  task process: :environment do
    processed = 0

    OutboxEvent.retryable.find_each do |event|
      event.enqueue!
      processed += 1
    end

    puts "outbox:process processed=#{processed}"
  end
end

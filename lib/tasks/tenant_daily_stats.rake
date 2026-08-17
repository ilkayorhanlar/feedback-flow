namespace :tenant_daily_stats do
  desc "Backfill tenant_daily_stats from already-aggregated feedbacks (one-time, not idempotent — do not rerun against a populated table)"
  task backfill: :environment do
    processed = 0

    Feedback.where(status: "aggregated").find_each(batch_size: 1000) do |feedback|
      TenantDailyStat.increment_for!(feedback)
      processed += 1
    end

    puts "tenant_daily_stats:backfill processed=#{processed}"
  end
end

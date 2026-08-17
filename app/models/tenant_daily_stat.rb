class TenantDailyStat < ApplicationRecord
  belongs_to :tenant

  def self.increment_for!(feedback)
    stat_date = (feedback.occurred_at || feedback.created_at).to_date
    score_sum_increment = feedback.score || 0
    score_count_increment = feedback.score.nil? ? 0 : 1

    sql = sanitize_sql_array([
      <<~SQL,
        INSERT INTO tenant_daily_stats (tenant_id, stat_date, feedback_count, score_sum, score_count, created_at, updated_at)
        VALUES (?, ?, 1, ?, ?, now(), now())
        ON CONFLICT (tenant_id, stat_date)
        DO UPDATE SET
          feedback_count = tenant_daily_stats.feedback_count + 1,
          score_sum = tenant_daily_stats.score_sum + excluded.score_sum,
          score_count = tenant_daily_stats.score_count + excluded.score_count,
          updated_at = now()
      SQL
      feedback.tenant_id, stat_date, score_sum_increment, score_count_increment
    ])

    connection.execute(sql)
  end

  def avg_score
    return nil if score_count.zero?

    score_sum.to_f / score_count
  end
end

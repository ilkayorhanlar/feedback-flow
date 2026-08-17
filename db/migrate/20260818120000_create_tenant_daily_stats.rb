class CreateTenantDailyStats < ActiveRecord::Migration[8.1]
  def change
    create_table :tenant_daily_stats do |t|
      t.references :tenant, null: false, foreign_key: true
      t.date :stat_date, null: false
      t.integer :feedback_count, null: false, default: 0
      t.bigint :score_sum, null: false, default: 0
      t.integer :score_count, null: false, default: 0

      t.timestamps
    end

    add_index :tenant_daily_stats, [ :tenant_id, :stat_date ], unique: true,
      name: "index_tenant_daily_stats_on_tenant_id_and_stat_date"

    add_check_constraint :tenant_daily_stats, "feedback_count >= 0", name: "tenant_daily_stats_feedback_count_non_negative"
    add_check_constraint :tenant_daily_stats, "score_sum >= 0", name: "tenant_daily_stats_score_sum_non_negative"
    add_check_constraint :tenant_daily_stats, "score_count >= 0 AND score_count <= feedback_count", name: "tenant_daily_stats_score_count_bounds"
  end
end

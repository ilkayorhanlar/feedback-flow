class CreateFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :feedbacks do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :external_id, null: false
      t.bigint :survey_id
      t.string :customer_id, null: false
      t.integer :score
      t.text :comment
      t.datetime :occurred_at
      t.string :status, null: false, default: "pending"
      t.string :sentiment
      t.string :webhook_status, null: false, default: "pending"
      t.datetime :webhook_sent_at

      t.timestamps
    end

    add_index :feedbacks, [:tenant_id, :external_id], unique: true
    add_index :feedbacks, :customer_id
    add_index :feedbacks, :survey_id

    add_check_constraint :feedbacks, "score IS NULL OR score BETWEEN 1 AND 5", name: "feedbacks_score_range"
    add_check_constraint :feedbacks, "status IN ('pending','sentiment_analyzed','aggregated')", name: "feedbacks_status_enum"
    add_check_constraint :feedbacks, "webhook_status IN ('pending','sent','failed')", name: "feedbacks_webhook_status_enum"
    add_check_constraint :feedbacks, "sentiment IS NULL OR sentiment IN ('positive','negative','neutral')", name: "feedbacks_sentiment_enum"
  end
end

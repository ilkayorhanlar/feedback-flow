# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_18_120100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "feedbacks", force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", null: false
    t.string "customer_id", null: false
    t.string "external_id", null: false
    t.datetime "occurred_at"
    t.integer "score"
    t.string "sentiment"
    t.string "status", default: "pending", null: false
    t.bigint "survey_id"
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.datetime "webhook_sent_at"
    t.string "webhook_status", default: "pending", null: false
    t.index ["customer_id"], name: "index_feedbacks_on_customer_id"
    t.index ["survey_id"], name: "index_feedbacks_on_survey_id"
    t.index ["tenant_id", "external_id"], name: "index_feedbacks_on_tenant_id_and_external_id", unique: true
    t.index ["tenant_id", "occurred_at"], name: "index_feedbacks_on_tenant_id_and_occurred_at", include: ["score"]
    t.index ["tenant_id"], name: "index_feedbacks_on_tenant_id"
    t.check_constraint "score IS NULL OR score >= 1 AND score <= 5", name: "feedbacks_score_range"
    t.check_constraint "sentiment IS NULL OR (sentiment::text = ANY (ARRAY['positive'::character varying, 'negative'::character varying, 'neutral'::character varying]::text[]))", name: "feedbacks_sentiment_enum"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'sentiment_analyzed'::character varying, 'aggregated'::character varying]::text[])", name: "feedbacks_status_enum"
    t.check_constraint "webhook_status::text = ANY (ARRAY['pending'::character varying, 'sent'::character varying, 'failed'::character varying]::text[])", name: "feedbacks_webhook_status_enum"
  end

  create_table "outbox_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.bigint "feedback_id", null: false
    t.datetime "lock_expires_at"
    t.datetime "processed_at"
    t.string "status", default: "pending", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["feedback_id"], name: "index_outbox_events_on_feedback_id"
    t.index ["lock_expires_at"], name: "index_outbox_events_on_lock_expires_at"
    t.index ["status"], name: "index_outbox_events_on_status"
    t.index ["tenant_id"], name: "index_outbox_events_on_tenant_id"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'enqueuing'::character varying, 'enqueued'::character varying]::text[])", name: "outbox_events_status_enum"
  end

  create_table "tenant_daily_stats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "feedback_count", default: 0, null: false
    t.integer "score_count", default: 0, null: false
    t.bigint "score_sum", default: 0, null: false
    t.date "stat_date", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "stat_date"], name: "index_tenant_daily_stats_on_tenant_id_and_stat_date", unique: true
    t.index ["tenant_id"], name: "index_tenant_daily_stats_on_tenant_id"
    t.check_constraint "feedback_count >= 0", name: "tenant_daily_stats_feedback_count_non_negative"
    t.check_constraint "score_count >= 0 AND score_count <= feedback_count", name: "tenant_daily_stats_score_count_bounds"
    t.check_constraint "score_sum >= 0", name: "tenant_daily_stats_score_sum_non_negative"
  end

  create_table "tenants", force: :cascade do |t|
    t.string "api_key", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["api_key"], name: "index_tenants_on_api_key", unique: true
  end

  add_foreign_key "feedbacks", "tenants"
  add_foreign_key "outbox_events", "feedbacks"
  add_foreign_key "outbox_events", "tenants"
  add_foreign_key "tenant_daily_stats", "tenants"
end

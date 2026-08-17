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

ActiveRecord::Schema[8.1].define(version: 2026_08_15_120030) do
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
    t.index ["tenant_id"], name: "index_feedbacks_on_tenant_id"
    t.check_constraint "score IS NULL OR score >= 1 AND score <= 5", name: "feedbacks_score_range"
    t.check_constraint "sentiment IS NULL OR (sentiment::text = ANY (ARRAY['positive'::character varying::text, 'negative'::character varying::text, 'neutral'::character varying::text]))", name: "feedbacks_sentiment_enum"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'sentiment_analyzed'::character varying::text, 'aggregated'::character varying::text])", name: "feedbacks_status_enum"
    t.check_constraint "webhook_status::text = ANY (ARRAY['pending'::character varying::text, 'sent'::character varying::text, 'failed'::character varying::text])", name: "feedbacks_webhook_status_enum"
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
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'enqueuing'::character varying::text, 'enqueued'::character varying::text])", name: "outbox_events_status_enum"
  end

  create_table "tenant_aggregates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "negative_count", default: 0, null: false
    t.integer "neutral_count", default: 0, null: false
    t.integer "positive_count", default: 0, null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_tenant_aggregates_on_tenant_id", unique: true
    t.check_constraint "negative_count >= 0", name: "tenant_aggregates_negative_count_non_negative"
    t.check_constraint "neutral_count >= 0", name: "tenant_aggregates_neutral_count_non_negative"
    t.check_constraint "positive_count >= 0", name: "tenant_aggregates_positive_count_non_negative"
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
  add_foreign_key "tenant_aggregates", "tenants"
end

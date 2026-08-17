class CreateOutboxEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :outbox_events do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :feedback, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :processed_at
      t.datetime :lock_expires_at

      t.timestamps
    end

    add_check_constraint :outbox_events, "status IN ('pending','enqueuing','enqueued')", name: "outbox_events_status_enum"
    add_index :outbox_events, :status
    add_index :outbox_events, :lock_expires_at
  end
end

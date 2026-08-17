class CreateTenantAggregates < ActiveRecord::Migration[8.1]
  def change
    create_table :tenant_aggregates do |t|
      t.references :tenant, null: false, foreign_key: true, index: { unique: true }
      t.integer :positive_count, null: false, default: 0
      t.integer :negative_count, null: false, default: 0
      t.integer :neutral_count, null: false, default: 0

      t.timestamps
    end

    add_check_constraint :tenant_aggregates, "positive_count >= 0", name: "tenant_aggregates_positive_count_non_negative"
    add_check_constraint :tenant_aggregates, "negative_count >= 0", name: "tenant_aggregates_negative_count_non_negative"
    add_check_constraint :tenant_aggregates, "neutral_count >= 0", name: "tenant_aggregates_neutral_count_non_negative"
  end
end

class AddTenantIdAndOccurredAtIndexToFeedbacks < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :feedbacks, [ :tenant_id, :occurred_at ], include: [ :score ],
      name: "index_feedbacks_on_tenant_id_and_occurred_at", algorithm: :concurrently
  end
end

class AddHostIdToProperties < ActiveRecord::Migration[8.1]
  def change
    add_reference :properties, :host, null: false, foreign_key: { to_table: :users }
    add_index :properties, :host_id
  end
end

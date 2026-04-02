class CreateConversations < ActiveRecord::Migration[7.0]
  def change
    create_table :conversations do |t|
      t.references :booking, null: false, foreign_key: true
      t.references :property, null: false, foreign_key: true
      t.integer :status, default: 0, null: false # active, archived, blocked
      t.datetime :last_message_at
      t.integer :last_message_by_id

      t.timestamps
    end

    add_index :conversations, :last_message_at
    add_index :conversations, [:booking_id, :property_id], unique: true

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }
      t.references :sender, null: false, polymorphic: true # User or Host
      t.text :body, null: false
      t.boolean :read, default: false, null: false
      t.datetime :read_at
      t.string :message_type, default: 'text' # text, system, attachment

      t.timestamps
    end

    add_index :messages, :read
    add_index :messages, :created_at
    add_index :messages, [:conversation_id, :read]
  end
end

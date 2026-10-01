class AddWhatsappFieldsToMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :client_message_id, :string unless column_exists?(:messages, :client_message_id)
    add_column :messages, :status, :integer, default: 0, null: false unless column_exists?(:messages, :status)
    add_column :messages, :wa_message_id, :string unless column_exists?(:messages, :wa_message_id)
    add_column :messages, :sent_at, :datetime unless column_exists?(:messages, :sent_at)
    add_column :messages, :delivered_at, :datetime unless column_exists?(:messages, :delivered_at)
    add_column :messages, :read_at_wa, :datetime unless column_exists?(:messages, :read_at_wa)

    add_column :conversations, :whatsapp_enabled, :boolean, default: true, null: false unless column_exists?(:conversations, :whatsapp_enabled)

    add_index :messages, [:conversation_id, :client_message_id], unique: true, name: 'idx_messages_conv_cmid' unless index_exists?(:messages, [:conversation_id, :client_message_id])
    add_index :messages, :wa_message_id unless index_exists?(:messages, :wa_message_id)
    add_index :messages, :status unless index_exists?(:messages, :status)

    # penanda reminder WA sudah dikirim utk angsuran ini (hindari spam harian)
    add_column :rental_installments, :reminder_sent_at, :datetime unless column_exists?(:rental_installments, :reminder_sent_at)
  end
end

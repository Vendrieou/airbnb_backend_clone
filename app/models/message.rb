class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender, polymorphic: true

  # Status pengiriman dua centang ala WhatsApp:
  #   pending(0) -> sent(1) [✓] -> delivered(2) [✓✓] -> read(3) [✓✓ biru]
  STATUSES = { pending: 0, sent: 1, delivered: 2, read: 3, failed: 4 }.freeze

  validates :body, presence: true, if: -> { message_type == 'text' }
  validates :message_type, inclusion: { in: %w[text system attachment] }
  validates :client_message_id, uniqueness: { scope: :conversation_id }, allow_nil: true

  before_validation :assign_client_message_id, on: :create

  after_create :update_conversation_timestamp
  after_create :dispatch_whatsapp!, if: -> { !system_message? && conversation.try(:whatsapp_enabled) != false }
  after_create :notify_recipient, if: -> { !system_message? }

  scope :unread, -> { where(read: false) }
  scope :read, -> { where(read: true) }
  scope :text_messages, -> { where(message_type: 'text') }
  scope :system_messages, -> { where(message_type: 'system') }

  def system_message?
    message_type == 'system'
  end

  def mark_as_read!
    update!(read: true, read_at: Time.current)
  end

  def status_name
    STATUSES.key(status.to_i).to_s
  end

  # Dipakai webhook provider WA (fonnte/wablas) utk update centang.
  def apply_delivery_status!(wa_status, at: Time.current)
    case wa_status.to_s
    when 'sent'
      update_columns(status: STATUSES[:sent], sent_at: sent_at || at)
    when 'delivered'
      update_columns(status: STATUSES[:delivered], sent_at: sent_at || at, delivered_at: delivered_at || at)
    when 'read'
      update_columns(status: STATUSES[:read], read_at_wa: read_at_wa || at)
      mark_as_read! unless read?
    when 'failed'
      update_columns(status: STATUSES[:failed])
    end
    broadcast_presence!
    self
  end

  def broadcast_presence!
    ActionCable.server.broadcast(
      "conversation_#{conversation_id}_channel",
      { type: 'message.status', message_id: id, status: status_name,
        sent_at: sent_at&.iso8601, delivered_at: delivered_at&.iso8601, read_at: read_at_wa&.iso8601 }
    )
  rescue StandardError => e
    Rails.logger.warn("[Message] broadcast status gagal: #{e.message}")
  end

  def recipient
    if sender.is_a?(User)
      conversation.booking.guest_id == sender.id ? conversation.property.host : conversation.booking.guest
    else
      conversation.other_participant(sender)
    end
  rescue StandardError
    conversation.other_participant(sender)
  end

  private

  def assign_client_message_id
    self.client_message_id ||= SecureRandom.uuid
    self.status = STATUSES[:pending] if status.nil?
  end

  # Kirim salinan pesan ke nomor WhatsApp lawan bicara (out-of-app notif),
  # lalu tandai 'sent' + broadcast centang via ActionCable.
  def dispatch_whatsapp!
    MessageWhatsappDeliveryJob.perform_later(id)
  rescue StandardError => e
    Rails.logger.warn("[Message] enqueue WA gagal: #{e.message}")
  end

  def update_conversation_timestamp
    conversation.update_columns(
      last_message_at: created_at,
      last_message_by_id: sender.is_a?(User) ? sender.id : nil
    )
  end

  def notify_recipient
    return if system_message?
    
    MessageNotificationJob.perform_later(self.id) if defined?(MessageNotificationJob)
  end
end

# Job: salin pesan in-app ke WhatsApp penerima (two-way feel ala WA).
# Provider dipilih via ENV["WHATSAPP_PROVIDER"] (fake|fonnte|wablas) — lihat WhatsappGateway.
class MessageWhatsappDeliveryJob < ApplicationJob
  queue_as :messaging

  retry_on StandardError, wait: 10.seconds, attempts: 3

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message
    return if message.system_message?

    conversation = message.conversation
    return if conversation.whatsapp_enabled == false

    recipient = message.recipient
    phone = recipient&.try(:phone)

    # Tanpa nomor: anggap terkirim di dalam app saja (centang tetap jalan utk in-app read).
    if phone.blank?
      message.apply_delivery_status!('sent')
      Rails.logger.info("[WA] skip: penerima tanpa nomor (pesan id=#{message.id})")
      return
    end

    sender_name = message.sender&.try(:name) || "Pengguna"
    body = "[Chat SewaCicil] #{sender_name}: #{message.body}"

    result = WhatsappGateway.deliver(phone: phone, body: body)
    if result.success
      message.update_columns(wa_message_id: result.provider_message_id, status: Message::STATUSES[:sent], sent_at: Time.current)
      message.broadcast_presence!
    else
      message.update_columns(status: Message::STATUSES[:failed])
      message.broadcast_presence!
      Rails.logger.warn("[WA] gagal kirim pesan #{message.id}: #{result.error}")
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end
end

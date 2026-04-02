class MessageBroadcaster < ApplicationService
  def initialize(message)
    @message = message
  end

  def call
    broadcast_message
    notify_recipient
  end

  private

  attr_reader :message

  def broadcast_message
    ActionCable.server.broadcast(
      "conversation_#{message.conversation_id}_channel",
      {
        type: 'message.created',
        message: serialize_message
      }
    )
  end

  def notify_recipient
    recipient = message.recipient
    return unless recipient

    Notification.create!(
      user: recipient,
      notifiable: message,
      notification_type: 'new_message',
      read: false
    ) if defined?(Notification)
  end

  def serialize_message
    {
      id: message.id,
      conversation_id: message.conversation_id,
      body: message.body,
      sender_id: message.sender_id,
      sender_type: message.sender_type,
      sender_name: message.sender&.name,
      created_at: message.created_at.iso8601,
      message_type: message.message_type,
      read: message.read
    }
  end
end

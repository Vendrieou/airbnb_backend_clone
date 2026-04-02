class MessageNotificationJob < ApplicationJob
  queue_as :default

  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(message_id)
    message = Message.find(message_id)
    recipient = message.recipient
    
    return unless recipient
    
    # Send email notification
    NotificationMailer.new_message(message).deliver_later if defined?(NotificationMailer)
    
    # Send push notification (if configured)
    # PushNotificationService.send(recipient, "New message from #{message.sender.name}")
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn("Message #{message_id} not found for notification")
  end
end

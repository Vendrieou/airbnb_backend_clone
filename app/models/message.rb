class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender, polymorphic: true

  validates :body, presence: true, if: -> { message_type == 'text' }
  validates :message_type, inclusion: { in: %w[text system attachment] }

  after_create :update_conversation_timestamp
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

  def recipient
    conversation.other_participant(sender)
  end

  private

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

class Conversation < ApplicationRecord
  belongs_to :booking
  belongs_to :property
  belongs_to :last_message_by, class_name: 'User', optional: true

  has_many :messages, -> { order(created_at: :asc) }, dependent: :destroy
  has_one :last_message, -> { order(created_at: :desc) }, class_name: 'Message'

  enum status: { active: 0, archived: 1, blocked: 2 }

  validates :booking_id, uniqueness: { scope: :property_id }

  after_create :initialize_participants

  delegate :guest, :host, to: :booking

  def participants
    [guest, host].compact.uniq
  end

  def other_participant(user)
    participants.find { |p| p.id != user.id }
  end

  def mark_as_read_by!(user)
    messages.unread.where.not(sender: user).update_all(read: true, read_at: Time.current)
  end

  def unread_count_for(user)
    messages.unread.where(sender: other_participant(user)).count
  end

  def latest_activity
    last_message_at || created_at
  end

  private

  def initialize_participants
    # Conversation is linked to booking which has guest and property which has host
  end
end

class Payout < ApplicationRecord
  belongs_to :host, class_name: 'User'
  belongs_to :payment, optional: true

  enum status: { pending: 0, paid: 1, failed: 2, cancelled: 3 }

  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :stripe_payout_id, uniqueness: true, allow_nil: true
  validates :stripe_account_id, presence: true

  scope :pending, -> { where(status: :pending) }
  scope :paid, -> { where(status: :paid) }
  scope :failed, -> { where(status: :failed) }
  scope :recent, -> { order(created_at: :desc) }

  def pay!
    update!(status: :paid, paid_at: Time.current)
  end

  def fail!(reason)
    update!(status: :failed, failure_reason: reason)
  end

  def cancel!
    return if paid? || cancelled?
    update!(status: :cancelled)
  end

  def formatted_amount
    "#{currency} #{sprintf('%.2f', amount)}"
  end
end

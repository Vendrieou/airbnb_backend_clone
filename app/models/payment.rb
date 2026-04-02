class Payment < ApplicationRecord
  belongs_to :booking

  enum status: { pending: 0, succeeded: 1, failed: 2, refunded: 3 }
  enum payment_method_type: { card: 'card', apple_pay: 'apple_pay', google_pay: 'google_pay' }

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :stripe_payment_intent_id, uniqueness: true, allow_nil: true

  scope :succeeded, -> { where(status: :succeeded) }
  scope :pending, -> { where(status: :pending) }
  scope :failed, -> { where(status: :failed) }
  scope :refunded, -> { where(status: :refunded) }
  scope :recent, -> { order(created_at: :desc) }

  def succeed!
    update!(status: :succeeded, paid_at: Time.current)
  end

  def fail!(reason)
    update!(status: :failed, failure_reason: reason)
  end

  def refund!(amount = nil)
    return if refunded?
    
    refund_amount = amount || self.amount
    update!(status: :refunded, refunded_at: Time.current, refund_amount: refund_amount)
  end

  def formatted_amount
    "#{currency} #{sprintf('%.2f', amount)}"
  end
end

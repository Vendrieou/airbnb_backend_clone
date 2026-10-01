# frozen_string_literal: true
#
# RentalInstallment = satu angsuran dari RentalInstallmentPlan.
class RentalInstallment < ApplicationRecord
  belongs_to :rental_installment_plan

  STATUSES = %w[pending paid overdue failed].freeze

  validates :number, presence: true, uniqueness: { scope: :rental_installment_plan_id }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :due_date, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :open, -> { where(status: %w[pending overdue]) }
  scope :paid, -> { where(status: 'paid') }
  scope :pending, -> { where(status: 'pending') }
  scope :overdue, -> { open.where("due_date < ?", Date.today) }

  def mark_paid!(payment_method: nil, reference: nil)
    update!(
      status: 'paid',
      paid_at: Time.current,
      payment_method: payment_method,
      payment_reference: reference
    )
  end

  def mark_overdue!
    update!(status: 'overdue') unless paid?
  end

  def overdue?(today = Date.today)
    return false if paid?

    due_date < today
  end

  def paid?
    status == 'paid'
  end

  def open?
    %w[pending overdue].include?(status)
  end

  def blank_record?
    new_record?
  end
end

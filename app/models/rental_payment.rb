# frozen_string_literal: true
#
# RentalPayment = catatan uang masuk untuk sebuah RentalBooking
# (bisa DP, angsuran, atau pelunasan).
class RentalPayment < ApplicationRecord
  belongs_to :rental_booking

  STATUSES = %w[pending succeeded failed refunded].freeze
  METHODS = %w[transfer card qris virtual_account cash other].freeze

  validates :amount, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :payment_method, inclusion: { in: METHODS }

  scope :succeeded, -> { where(status: 'succeeded') }

  def succeed!
    was_succeeded = status == 'succeeded'
    transaction do
      update!(status: 'succeeded', paid_at: Time.current) unless was_succeeded
      apply_to_booking! unless was_succeeded
    end
  end

  def fail!(reason)
    update!(status: 'failed', failure_reason: reason)
  end

  def refund!
    return if status == 'refunded'

    update!(status: 'refunded', refunded_at: Time.current)
    booking = rental_booking
    booking.with_lock do
      new_total = [booking.amount_paid - amount, 0].max
      booking.update_columns(amount_paid: new_total)
      booking.sync_payment_state!
    end
  end

  private

  # Tumpuk ke amount_paid booking lalu cocokkan ke angsuran terkecil yang belum lunas
  def apply_to_booking!
    booking = rental_booking
    booking.with_lock do
      booking.update_columns(amount_paid: booking.amount_paid + amount)
      apply_to_installments(booking, amount)
      booking.sync_payment_state!
    end
  end

  def apply_to_installments(booking, payment_amount)
    plan = booking.installment_plan
    return if plan.blank?

    remaining = payment_amount
    plan.installments.open.order(:number).each do |installment|
      break if remaining <= 0

      owed = installment.amount + installment.late_fee - installment.amount_paid
      next if owed <= 0

      applied = [owed, remaining].min
      installment.update_columns(amount_paid: installment.amount_paid + applied)
      remaining -= applied

      installment.mark_paid!(payment_method: payment_method, reference: id) if applied >= owed
    end
  end
end

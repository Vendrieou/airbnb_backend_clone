# frozen_string_literal: true
#
# RentalInstallmentPayer = memproses satu pembayaran pada booking sewa:
#   - DP (down payment) untuk booking yang dicicil
#   - angsuran bulanan sesuai jadwal
#   - pelunasan (bisa bayar lebih awal / early payoff)
#
# Setelah pembayaran succeeded, otomatis:
#   1. mencocokkan dana ke angsuran tertua yang belum lunas
#   2. sinkronkan payment_status booking (via RentalBooking#sync_payment_state!)
class RentalInstallmentPayer
  include ErrorHandling

  Result = Struct.new(:payment, :errors, keyword_init: true) do
    def success?
      errors.blank?
    end
  end

  def initialize(booking:, amount:, payment_method: 'transfer', reference: nil, kind: nil)
    @booking = booking
    @amount = BigDecimal(amount.to_s)
    @payment_method = payment_method
    @reference = reference
    @kind = kind
  end

  def call
    validate!

    ActiveRecord::Base.transaction do
      payment = booking.payments.create!(
        amount: amount,
        currency: booking.currency.presence || 'IDR',
        payment_method: payment_method,
        reference: reference,
        kind: resolved_kind,
        status: 'pending'
      )

      # succeed! -> catat amount_paid, cocokkan ke angsuran, sinkronkan status
      payment.succeed!
      notify_payment!(payment)
      Result.new(payment: payment.reload)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.new(errors: e.record.errors.full_messages)
  rescue BookingError => e
    Result.new(errors: [e.message])
  end

  private

  attr_reader :booking, :amount, :payment_method, :reference, :kind

  def validate!
    raise BookingError, "Booking not found" if booking.blank?
    raise BookingError, "Amount must be positive" unless amount&.positive?
    raise BookingError, "Booking is cancelled" if booking.status.in?(%w[cancelled_by_guest cancelled_by_host rejected])
    raise BookingError, "Booking already fully paid" if booking.fully_paid?
    raise BookingError, "Payment method not supported" unless RentalPayment::METHODS.include?(payment_method)
  end

  # Kirim struk pembayaran via WhatsApp (non-blocking; provider 'fake' = log saja)
  def notify_payment!(payment)
    RentalPaymentNotificationJob.perform_later(payment.id)
  rescue StandardError => e
    Rails.logger.warn("[Payer] enqueue notif WA gagal: #{e.message}")
  end

  def resolved_kind
    return kind if kind.present?

    if booking.installment_plan.nil?
      'final_payment'
    elsif booking.amount_paid.zero?
      'down_payment'
    elsif booking.remaining_balance <= amount
      'final_payment'
    else
      'installment'
    end
  end
end

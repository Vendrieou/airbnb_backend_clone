# frozen_string_literal: true
#
# RentalInstallmentPlan = skema cicilan ("dicicil") untuk sebuah RentalBooking.
#
# Cara kerja:
#   1. DP (down payment) = upfront_percent x total_price, dibayar di muka.
#   2. Sisa saldo dipecah rata menjadi installment_count angsuran.
#      Interval jatuh tempo mengikuti installment_interval_days (default 30 hari).
#   3. Jadwal angsuran dibangun via #generate_schedule! dan disimpan saat
#      RentalBookingCreator menjalankan transaksinya.
class RentalInstallmentPlan < ApplicationRecord
  belongs_to :rental_booking
  belongs_to :rental_plan, optional: true

  has_many :installments, class_name: 'RentalInstallment',
                          foreign_key: :rental_installment_plan_id,
                          dependent: :destroy

  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :down_payment, numericality: { greater_than_or_equal_to: 0 }
  validates :installment_count, numericality: { greater_than: 0 }
  validate :down_payment_within_total

  scope :active, -> { joins(:rental_booking).merge(RentalBooking.not_cancelled) }
  scope :open, -> { where(status: %w[pending active]) }

  # Total yang benar-benar sudah terbayar untuk skema ini.
  # Sumber kebenaran: kolom paid_amount (di-update lewat sync_state!),
  # dengan fallback penghitungan dari angsuran yang lunas.
  def paid_amount
    return self[:paid_amount] if persisted? && self[:paid_amount].to_d > 0

    installments.loaded? ?
      installments.select(&:paid?).sum { |i| i.amount_paid.to_d } :
      installments.where(status: 'paid').sum(:amount_paid).to_d
  end

  def remaining_amount
    total_balance - paid_amount
  end

  def overdue?
    if installments.loaded?
      installments.any? { |i| !i.paid? && i.due_date.present? && i.due_date < Date.today }
    else
      installments.overdue.exists?
    end
  end

  def completed?
    return false if installment_count.zero?

    if installments.loaded?
      installments.reject(&:blank_record?).all?(&:paid?)
    else
      installments.any? && !installments.open.exists?
    end
  end

  def next_due_installment
    if installments.loaded?
      installments.reject(&:blank_record?).select(&:open?).min_by(&:due_date)
    else
      installments.open.order(:due_date).first
    end
  end

  # Bangun jadwal angsuran DI MEMORY (belum disimpan).
  # Dipakai untuk menyimpan jadwal maupun estimasi/preview. Idempotent.
  def generate_schedule!
    return self if @schedule_generated || persisted?

    balance = total_balance
    base = (balance / installment_count).round(2)
    collected = BigDecimal("0")
    start_from = first_due_date

    installment_count.times do |index|
      amount =
        if index == installment_count - 1
          # cicilan terakhir menyerap sisa pembulatan
          balance - collected
        else
          base
        end
      collected += amount

      installments.build(
        number: index + 1,
        amount: amount,
        due_date: (start_from + (index * installment_interval_days).days).to_date,
        status: 'pending'
      )
    end

    @schedule_generated = true
    self
  end

  # Simpan jadwal ke DB bila belum ada angsuran tersimpan.
  def save_schedule!
    return self if installments.exists?

    generate_schedule!.save!
  end

  # Sinkronkan plan & booking setelah ada pembayaran baru.
  def sync_state!
    reload
    update!(
      paid_amount: paid_amount,
      next_due_date: next_due_installment&.due_date,
      status: compute_status
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Installment plan sync failed: #{e.message}"
  end

  private

  def total_balance
    total_amount - down_payment
  end

  def first_due_date
    # Angsuran pertama jatuh tempo satu interval setelah booking dibuat
    rental_booking.created_at.to_date
  end

  def compute_status
    return 'completed' if completed?
    return 'overdue' if overdue?
    return 'pending' if paid_amount.zero?

    'active'
  end

  def down_payment_within_total
    return if total_amount.blank? || down_payment.blank?

    if down_payment > total_amount
      errors.add(:down_payment, "cannot exceed total amount")
    elsif installment_count > 0 && (total_amount - down_payment).negative?
      errors.add(:down_payment, "leaves a negative balance")
    end
  end
end

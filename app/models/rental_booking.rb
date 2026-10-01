# frozen_string_literal: true
#
# RentalBooking = transaksi sewa sebuah facility lewat RentalPlan
# (harian / mingguan / bulanan). Pembayaran bisa lunas atau dicicil
# (lihat RentalInstallmentPlan & RentalInstallment).
class RentalBooking < ApplicationRecord
  include ErrorHandling

  STATUSES = %w[pending_payment confirmed active completed
                cancelled_by_guest cancelled_by_host rejected].freeze
  PAYMENT_STATUSES = %w[unpaid down_payment_paid partially_paid paid overdue refunded].freeze

  belongs_to :rental_plan
  belongs_to :facility
  belongs_to :property
  belongs_to :guest, class_name: 'User', foreign_key: :user_id
  belongs_to :host, class_name: 'User', foreign_key: :host_id

  has_one :installment_plan, class_name: 'RentalInstallmentPlan',
                             foreign_key: :rental_booking_id,
                             dependent: :destroy
  has_many :payments, -> { order(created_at: :asc) },
           class_name: 'RentalPayment',
           foreign_key: :rental_booking_id,
           dependent: :restrict_with_error

  validates :start_date, :end_date, :idempotency_key, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :total_price, numericality: { greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :payment_status, inclusion: { in: PAYMENT_STATUSES }
  validate :date_range_validity
  validate :period_alignment

  before_save :calculate_totals

  scope :not_cancelled, -> { where.not(status: %w[cancelled_by_guest cancelled_by_host rejected]) }
  scope :pending_payment, -> { where(status: 'pending_payment') }
  scope :confirmed, -> { where(status: 'confirmed') }
  scope :active, -> { where(status: 'active') }
  scope :completed, -> { where(status: 'completed') }
  scope :current_and_upcoming, -> { where("end_date >= ?", Date.today).not_cancelled }
  scope :for_property, ->(property_id) { where(property_id: property_id) }
  scope :by_payment_status, ->(status) { where(payment_status: status) }

  def installment?
    installment_plan.present?
  end

  def fully_paid?
    payment_status == 'paid'
  end

  def remaining_balance
    total_price - amount_paid
  end

  def confirmable?
    pending_payment? && (pay_later? || amount_paid >= total_price)
  end

  def confirm!
    update!(status: 'confirmed')
  end

  def activate!
    update!(status: 'active') if confirmed? && start_date <= Date.today
  end

  def complete!
    update!(status: 'completed', payment_status: 'paid') if active? || confirmed?
  end

  def cancel_by_guest!(reason = nil)
    update!(
      status: 'cancelled_by_guest',
      cancelled_at: Time.current,
      cancel_reason: reason
    )
  end

  def cancel_by_host!(reason = nil)
    update!(
      status: 'cancelled_by_host',
      cancelled_at: Time.current,
      cancel_reason: reason
    )
  end

  # Dipanggil setelah pembayaran tercatat: sinkronkan payment_status & booking
  # Dipanggil setelah pembayaran tercatat: sinkronkan payment_status & status booking.
  def sync_payment_state!
    reload # ambil amount_paid terbaru (di-update via update_columns)

    attrs = { payment_status: compute_payment_status }

    if attrs[:payment_status] != 'unpaid' && pending_payment?
      attrs[:status] = 'confirmed'
    end

    effective_status = attrs[:status] || status
    if effective_status == 'confirmed' && start_date <= Date.today
      attrs[:status] = 'active'
    end

    # Jangan turunkan booking yang sudah lunas kembali ke pending_payment
    if attrs == { payment_status: payment_status } || (attrs.size == 1 && attrs.key?(:payment_status) && attrs[:payment_status] == payment_status)
      return
    end

    assign_attributes(attrs)
    save!

    installment_plan&.sync_state!
  end

  private

  def pending_payment?
    status == 'pending_payment'
  end

  def confirmed?
    status == 'confirmed'
  end

  def active?
    status == 'active'
  end

  def pay_later?
    installment_plan.present? ? installment_plan.down_payment.zero? : false
  end

  def compute_payment_status
    paid = amount_paid.to_d
    total = total_price.to_d
    dp = down_payment.to_d

    if paid >= total && total.positive?
      'paid'
    elsif paid >= dp && dp.positive? && paid.positive?
      'partially_paid'
    elsif paid.positive?
      'down_payment_paid'
    else
      'unpaid'
    end
  end

  def date_range_validity
    return if start_date.blank? || end_date.blank?

    RentalPlan.validate_dates!(start_date, end_date)
  rescue InvalidDateRangeError => e
    errors.add(:base, e.message)
  end

  def period_alignment
    return if start_date.blank? || end_date.blank? || rental_plan.blank?

    rental_plan.validate_period_alignment!(start_date, end_date)
  rescue RentalPeriodMismatchError => e
    errors.add(:base, e.message)
  end

  def calculate_totals
    return if rental_plan.blank? || quantity.blank?

    gross = rental_plan.price * quantity
    net = rental_plan.total_price_for(quantity)

    self.price = gross
    self.discount = gross - net
    self.total_price = net

    # Snapshot kebijakan cicilan plan agar riwayat tidak berubah saat plan diedit
    self.upfront_percent = rental_plan.upfront_percent if installment_enabled_snapshot?
    self.installment_count = rental_plan.installment_count if installment_enabled_snapshot?

    pct = upfront_percent.to_d
    self.down_payment = (net * pct / 100).round(2)
  end

  def installment_enabled_snapshot?
    @creator_installment || installment_count.to_i > 0
  end

  attr_writer :creator_installment
end

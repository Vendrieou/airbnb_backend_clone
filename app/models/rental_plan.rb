# frozen_string_literal: true
#
# RentalPlan = paket sewa untuk sebuah facility dengan durasi tertentu.
#
# Periode yang didukung:
#   daily    -> sewa harian
#   weekly   -> sewa mingguan (biasanya lebih murah dari 7x harian)
#   monthly  -> sewa bulanan (diskon lebih besar lagi)
#
# Jika +installment_enabled+ true, penyewa bisa membayar dengan cara dicicil
# (DP + angsuran otomatis via RentalInstallmentPlan).
class RentalPlan < ApplicationRecord
  include ErrorHandling

  PERIODS = %w[daily weekly monthly].freeze

  belongs_to :facility
  belongs_to :host, class_name: 'User'

  has_many :rental_bookings, dependent: :restrict_with_error
  has_many :rental_installment_plans, through: :rental_bookings, source: :installment_plan

  validates :period, inclusion: { in: PERIODS }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :min_quantity, numericality: { greater_than: 0 }
  validates :max_advance_days, numericality: { greater_than: 0 }
  validates :upfront_percent, numericality: { in: 0..100 }
  validates :installment_count, numericality: {
    greater_than: 0, less_than_or_equal_to: 36
  }, if: :installment_enabled?

  scope :active, -> { where(active: true) }
  scope :daily, -> { where(period: 'daily') }
  scope :weekly, -> { where(period: 'weekly') }
  scope :monthly, -> { where(period: 'monthly') }
  scope :with_installments, -> { where(installment_enabled: true) }
  scope :for_facility, ->(facility_id) { where(facility_id: facility_id) }

  def daily?
    period == 'daily'
  end

  def weekly?
    period == 'weekly'
  end

  def monthly?
    period == 'monthly'
  end

  # Jumlah hari dalam satu unit periode sewa
  def days_per_unit
    case period
    when 'weekly' then 7
    when 'monthly' then 30
    else 1
    end
  end

  # Total harga untuk +quantity+ unit periode, sudah dipotong diskon plan
  def total_price_for(quantity)
    subtotal = price * quantity
    subtotal - (subtotal * discount_percent / 100.0)
  end

  # Estimasi skema cicilan tanpa menyimpan apa pun (untuk preview ke user)
  def installment_estimate(total_amount)
    return nil unless installment_enabled?

    RentalInstallmentPlan.new(rental_plan: self, total_amount: total_amount).tap(&:generate_schedule!)
  end

  def available_for?(start_date, end_date)
    RentalPlan.validate_dates!(start_date, end_date)

    if start_date < Date.today + min_advance_days
      raise InvalidDateRangeError,
            "Minimal H-#{min_advance_days} hari sebelum tanggal mulai"
    end

    if start_date > Date.today + max_advance_days
      raise InvalidDateRangeError,
            "Maksimal pemesanan #{max_advance_days} hari ke depan"
    end

    overlapping = rental_bookings
      .where("start_date < ? AND end_date > ?", end_date, start_date)
      .not_cancelled
      .exists?

    !overlapping
  rescue RentalPeriodMismatchError
    raise
  end

  # Validasi bahwa rentang tanggal cocok dengan kelipatan periode sewa
  def self.validate_dates!(start_date, end_date)
    raise InvalidDateRangeError, "End date must be after start date" if end_date <= start_date
    raise InvalidDateRangeError, "Start date cannot be in the past" if start_date < Date.today
  end

  def validate_period_alignment!(start_date, end_date)
    nights = (end_date - start_date).to_i

    if nightly?
      raise RentalPeriodMismatchError, "Sewa harian minimal 1 malam" if nights < 1
    elsif weekly?
      unless nights % 7 == 0
        raise RentalPeriodMismatchError,
              "Sewa mingguan harus kelipatan 7 malam (dapat #{nights} malam)"
      end
    elsif monthly?
      unless nights % 30 == 0
        raise RentalPeriodMismatchError,
              "Sewa bulanan harus kelipatan 30 malam (dapat #{nights} malam)"
      end
    end
  end

  def nightly?
    daily?
  end
end

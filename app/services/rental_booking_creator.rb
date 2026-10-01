# frozen_string_literal: true
#
# RentalBookingCreator = membuat booking sewa (harian/mingguan/bulanan),
# opsional dengan skema cicilan (installment).
#
# Alur:
#   1. Validasi tanggal + kelipatan periode (daily/weekly/monthly)
#   2. Cek idempotency key (cegah submit ganda)
#   3. Lock baris RentalPlan, cek ketersediaan rentang tanggal
#   4. Hitung harga; jika pay_in_installments -> buat DP + jadwal angsuran
class RentalBookingCreator
  include ErrorHandling

  Result = Struct.new(:booking, :errors, keyword_init: true) do
    def success?
      errors.blank?
    end
  end

  def initialize(rental_plan:, guest:, start_date:, end_date:,
                 quantity: 1, pay_in_installments: false,
                 special_requests: nil, idempotency_key: nil)
    @rental_plan = rental_plan
    @guest = guest
    @start_date = Date.parse(start_date.to_s)
    @end_date = Date.parse(end_date.to_s)
    @quantity = quantity.to_i
    @pay_in_installments = ActiveModel::Type::Boolean.new.cast(pay_in_installments)
    @special_requests = special_requests
    @idempotency_key = idempotency_key || SecureRandom.uuid
  end

  def call
    validate_input!

    ActiveRecord::Base.transaction do
      rental_plan.with_lock do
        existing = RentalBooking.find_by(idempotency_key: idempotency_key)
        return Result.new(booking: existing) if existing

        unless rental_plan.active? && rental_plan.facility.active?
          raise PropertyUnavailableError, "Rental plan is not active"
        end

        unless rental_plan.available_for?(start_date, end_date)
          raise PropertyUnavailableError,
                "Sudah ada sewa lain pada rentang tanggal tersebut"
        end

        booking = build_booking
        booking.save!
        create_installment_plan!(booking) if pay_in_installments && booking.installment_count.positive?

        Result.new(booking: booking.reload)
      end
    end
  rescue ActiveRecord::RecordNotUnique
    Result.new(errors: ["Duplicate booking detected"])
  rescue BookingError => e
    Result.new(errors: [e.message])
  rescue ArgumentError => e
    Result.new(errors: ["Invalid date format: #{e.message}"])
  rescue ActiveRecord::RecordInvalid => e
    Result.new(errors: e.record.errors.full_messages)
  end

  private

  attr_reader :rental_plan, :guest, :start_date, :end_date, :quantity,
              :pay_in_installments, :special_requests, :idempotency_key

  def validate_input!
    RentalPlan.validate_dates!(start_date, end_date)
    raise InvalidDateRangeError, "Quantity must be at least 1" if quantity < 1
    raise InvalidDateRangeError, "Minimal #{rental_plan.min_quantity} unit" if quantity < rental_plan.min_quantity

    rental_plan.validate_period_alignment!(start_date, end_date)
  end

  def build_booking
    RentalBooking.new(
      rental_plan: rental_plan,
      facility: rental_plan.facility,
      property: rental_plan.facility.property,
      guest: guest,
      host: rental_plan.host,
      start_date: start_date,
      end_date: end_date,
      quantity: quantity,
      special_requests: special_requests,
      idempotency_key: idempotency_key,
      status: 'pending_payment',
      payment_status: 'unpaid',
      currency: 'IDR'
    ).tap { |b| b.creator_installment = pay_in_installments }
  end

  def create_installment_plan!(booking)
    plan = RentalInstallmentPlan.new(
      rental_booking: booking,
      rental_plan: rental_plan,
      total_amount: booking.total_price,
      down_payment: booking.down_payment,
      installment_count: booking.installment_count,
      installment_interval_days: rental_plan.installment_interval_days,
      status: 'pending'
    )
    plan.save!
    plan.save_schedule! # bangun + simpan jadwal angsuran
  end
end

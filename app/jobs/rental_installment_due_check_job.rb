# frozen_string_literal: true
#
# Jalankan harian (mis. via cron/GoodJob):
#   RentalInstallmentDueCheckJob.perform_later
#
# 1. Tandai angsuran yang lewat jatuh tempo sebagai 'overdue'
# 2. Sinkronkan payment_status booking menjadi 'overdue'
# 3. Aktifkan booking confirmed yang sudah mulai (start_date <= hari ini)
class RentalInstallmentDueCheckJob < ApplicationJob
  queue_as :default

  def perform
    today = Date.today

    RentalInstallment.open.where("due_date < ?", today).find_each do |installment|
      installment.update!(status: 'overdue')
    end

    RentalInstallmentPlan.where(status: %w[pending active])
                         .joins(:rental_booking)
                         .merge(RentalBooking.not_cancelled)
                         .find_each do |plan|
      plan.sync_state!
      booking = plan.rental_booking

      if plan.overdue? && !booking.fully_paid?
        booking.update!(payment_status: 'overdue')
      end
    end

    RentalBooking.confirmed.where("start_date <= ?", today).find_each(&:activate!)
    RentalBooking.active.where("end_date < ?", today).find_each(&:complete!)
  end
end

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

  REMINDER_DAYS_BEFORE = 3 # H-3 sebelum jatuh tempo (konsep sama dgn grace housekeeping)

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

    send_due_reminders!(today)

    RentalBooking.confirmed.where("start_date <= ?", today).find_each(&:activate!)
    RentalBooking.active.where("end_date < ?", today).find_each(&:complete!)
  end
end

  private

  # Pengingat WhatsApp: H-3 sebelum jatuh tempo, hari-H, dan mingguan saat overdue.
  def send_due_reminders!(today)
    RentalInstallment.open.find_each do |inst|
      guest = inst.plan.rental_booking.guest rescue next
      next unless guest
      notifier = WhatsappNotifier.new(guest)
      next if inst.reminder_sent_at.present? # sudah pernah dapat reminder utk angsuran ini

      if inst.due_date == today || inst.due_date == today + REMINDER_DAYS_BEFORE
        notifier.installment_due(inst)
        inst.update_columns(reminder_sent_at: Time.current)
      elsif inst.status == "overdue" && (today - inst.due_date).to_i % 7 == 0
        notifier.installment_due(inst)
      end
    end
  rescue StandardError => e
    Rails.logger.warn("[DueCheck] reminder error: #{e.message}")
  end
end

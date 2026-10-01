# Konfirmasi booking sewa (termasuk skema cicilan) dikirim ke guest via WhatsApp.
class RentalBookingNotificationJob < ApplicationJob
  queue_as :messaging

  def perform(booking_id)
    booking = RentalBooking.includes(:rental_plan, :guest).find_by(id: booking_id)
    return unless booking&.guest

    WhatsappNotifier.new(booking.guest).booking_created(booking)
  rescue StandardError => e
    Rails.logger.warn("[RentalBookingNotificationJob] #{e.message}")
  end
end

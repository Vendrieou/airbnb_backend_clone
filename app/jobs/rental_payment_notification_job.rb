# Struk pembayaran (DP / angsuran / pelunasan) dikirim ke guest via WhatsApp.
class RentalPaymentNotificationJob < ApplicationJob
  queue_as :messaging

  def perform(payment_id)
    payment = RentalPayment.find_by(id: payment_id, status: "succeeded")
    return unless payment
    booking = payment.rental_booking
    return unless booking&.guest

    WhatsappNotifier.new(booking.guest).payment_received(booking, payment.amount)
  rescue StandardError => e
    Rails.logger.warn("[RentalPaymentNotificationJob] #{e.message}")
  end
end

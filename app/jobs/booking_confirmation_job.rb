class BookingConfirmationJob < ApplicationJob
  queue_as :default

  def perform(booking_id)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    # Logika pengiriman email (gunakan ActionMailer di tahap produksi)
    Rails.logger.info "================================================="
    Rails.logger.info "MEMPROSES BACKGROUND JOB: Mengirim email konfirmasi"
    Rails.logger.info "Booking ID: #{booking.id} | Properti: #{booking.property.name}"
    Rails.logger.info "================================================="
  end
end

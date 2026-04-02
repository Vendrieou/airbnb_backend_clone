class FacilityBookingMailer < ApplicationMailer
  default from: 'bookings@example.com'

  def confirmation_email(booking)
    @booking = booking
    @guest = booking.guest
    mail(
      to: @guest.email,
      subject: "Booking Confirmation - #{@booking.facility.name} on #{@booking.booking_date}"
    )
  end

  def host_notification(booking)
    @booking = booking
    @host = booking.host
    mail(
      to: @host.email,
      subject: "New Facility Booking - #{@booking.facility.name}"
    )
  end

  def reminder_email(booking)
    @booking = booking
    @guest = booking.guest
    mail(
      to: @guest.email,
      subject: "Reminder: Your booking is tomorrow - #{@booking.facility.name}"
    )
  end

  def cancellation_email(booking, recipient_type)
    @booking = booking
    @recipient = recipient_type == :guest ? booking.guest : booking.host
    mail(
      to: @recipient.email,
      subject: "Booking Cancelled - #{@booking.facility.name}"
    )
  end
end

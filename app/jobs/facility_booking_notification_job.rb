class FacilityBookingNotificationJob < ApplicationJob
  queue_as :default

  def perform(booking_id, notification_type)
    booking = FacilityBooking.find_by(id: booking_id)
    return unless booking

    case notification_type
    when :guest_confirmation
      send_guest_confirmation(booking)
    when :host_notification
      send_host_notification(booking)
    when :reminder
      send_reminder(booking)
    when :cancellation
      send_cancellation_notice(booking)
    end
  end

  private

  def send_guest_confirmation(booking)
    # Send email confirmation to guest
    FacilityBookingMailer.confirmation_email(booking).deliver_later
    
    # Optional: Send SMS if phone number available
    # SmsService.send(booking.guest.phone, "Your facility booking is confirmed!")
  end

  def send_host_notification(booking)
    # Notify host about new booking
    FacilityBookingMailer.host_notification(booking).deliver_later
  end

  def send_reminder(booking)
    # Send reminder 24 hours before booking
    FacilityBookingMailer.reminder_email(booking).deliver_later
  end

  def send_cancellation_notice(booking)
    # Notify both parties about cancellation
    FacilityBookingMailer.cancellation_email(booking, :guest).deliver_later
    FacilityBookingMailer.cancellation_email(booking, :host).deliver_later
  end
end

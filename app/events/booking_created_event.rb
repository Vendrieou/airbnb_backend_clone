module Events
  class BookingCreatedEvent
    def initialize(booking)
      @booking = booking
    end

    def publish
      Rails.logger.info "Publishing BookingCreatedEvent for booking ##{@booking.id}"
      
      # Async job for confirmation email
      BookingConfirmationJob.perform_later(@booking.id)
      
      # Could also notify other services via message queue
      # Example: NotificationService.send_booking_confirmation(@booking)
      
      ActiveSupport::Notifications.instrument(
        'booking.created', 
        booking_id: @booking.id,
        property_id: @booking.property_id,
        user_id: @booking.user_id
      )
    end
  end
end

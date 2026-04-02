class FacilityBookingCreator
  include ErrorHandling
  
  def initialize(facility, property, user, host, booking_date, start_time, quantity, special_requests = nil)
    @facility = facility
    @property = property
    @user = user
    @host = host
    @booking_date = booking_date
    @start_time = start_time
    @quantity = quantity
    @special_requests = special_requests
    @idempotency_key = SecureRandom.uuid
  end
  
  def call
    # Check if facility is available
    unless @facility.bookable?(@booking_date, @start_time, @quantity)
      throw(:halt, { error: "Facility is not available for the selected time slot" })
    end
    
    # Create the booking
    booking = FacilityBooking.new(
      facility: @facility,
      property: @property,
      guest: @user,
      host: @host,
      booking_date: @booking_date,
      start_time: @start_time,
      end_time: @start_time.to_time + @facility.slot_interval_minutes.minutes,
      quantity: @quantity,
      price: @facility.price,
      discount: calculate_discount,
      discount_percent: calculate_discount_percent,
      special_requests: @special_requests,
      idempotency_key: @idempotency_key,
      status: 'pending'
    )
    
    catch(:halt) do
      if booking.save
        # Notify host about new booking (optional: implement notification service)
        notify_host(booking)
        booking
      else
        throw(:halt, booking)
      end
    end
  end
  
  private
  
  def calculate_discount
    # Implement member tier discounts here
    # For now, return 0
    0.0
  end
  
  def calculate_discount_percent
    # Implement member tier discount percentages
    # Example: Silver 10%, Gold 15%, Platinum 20%
    # This would check user's member type and return appropriate percentage
    0.0
  end
  
  def notify_host(booking)
    # TODO: Implement host notification (email, push notification, etc.)
    # Example: HostNotificationMailer.new_facility_booking(booking).deliver_later
  end
end

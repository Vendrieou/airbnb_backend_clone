class FacilityBookingCreator
  include ErrorHandling
  
  def initialize(facility, property, user, host, booking_date, start_time, quantity, special_requests = nil, idempotency_key = nil)
    @facility = facility
    @property = property
    @user = user
    @host = host
    @booking_date = booking_date
    @start_time = start_time
    @quantity = quantity
    @special_requests = special_requests
    @idempotency_key = idempotency_key || SecureRandom.uuid
  end
  
  def call
    ActiveRecord::Base.transaction do
      # Check for idempotency - prevent duplicate submissions
      if @idempotency_key && FacilityBooking.exists?(idempotency_key: @idempotency_key)
        existing_booking = FacilityBooking.find_by(idempotency_key: @idempotency_key)
        throw(:halt, { error: "Duplicate booking request", booking: existing_booking })
      end
      
      # Check real-time availability with row-level locking
      unless check_realtime_availability
        throw(:halt, { error: "Facility is not available for the selected time slot" })
      end
      
      # Calculate pricing with member discounts
      base_price = @facility.price * @quantity
      discount_amount, discount_percent = calculate_member_discounts(base_price)
      total_price = base_price - discount_amount
      
      # Create the booking
      booking = FacilityBooking.new(
        facility: @facility,
        property: @property,
        guest: @user,
        host: @host,
        booking_date: @booking_date,
        start_time: @start_time,
        end_time: calculate_end_time,
        quantity: @quantity,
        price: @facility.price,
        total_price: total_price,
        discount: discount_amount,
        discount_percent: discount_percent,
        special_requests: @special_requests,
        idempotency_key: @idempotency_key,
        status: 'pending_payment', # Requires payment confirmation
        currency: 'USD'
      )
      
      catch(:halt) do
        if booking.save
          # Award loyalty points if applicable
          award_loyalty_points(booking) if booking.total_price > 0
          
          # Send notifications asynchronously
          send_notifications(booking)
          
          booking
        else
          throw(:halt, booking)
        end
      end
    end
  end
  
  private
  
  def check_realtime_availability
    # Use SELECT FOR UPDATE to prevent race conditions
    locked_facility = Facility.lock.find(@facility.id)
    locked_facility.bookable?(@booking_date, @start_time, @quantity)
  end
  
  def calculate_end_time
    @start_time.to_time + (@facility.slot_interval_minutes || 60) * @quantity * 60
  end
  
  def calculate_member_discounts(base_price)
    return [0.0, 0.0] unless @user.respond_to?(:member_type)
    
    member_type = @user.member_type
    return [0.0, 0.0] unless member_type
    
    # Member tier discounts based on your database schema
    discount_percent = case member_type.name
                       when 'Silver' then 10.0
                       when 'Gold' then 15.0
                       when 'Platinum' then 20.0
                       else 0.0
                       end
    
    discount_amount = base_price * (discount_percent / 100.0)
    [discount_amount, discount_percent]
  end
  
  def award_loyalty_points(booking)
    # Award 1 point per $10 spent (adjust as needed)
    points_earned = (booking.total_price / 10).floor
    return if points_earned <= 0
    
    MemberPoint.create!(
      user: @user,
      facility_booking: booking,
      points: points_earned,
      source: 'facility_booking',
      expires_at: 1.year.from_now
    )
    
    # Update user's total points
    @user.increment!(:loyalty_points, points_earned)
  end
  
  def send_notifications(booking)
    # Queue notifications via Solid Queue (Rails 8 built-in)
    FacilityBookingNotificationJob.perform_later(booking.id, :guest_confirmation)
    FacilityBookingNotificationJob.perform_later(booking.id, :host_notification)
  end
end

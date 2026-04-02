class BookingCreator
  include ErrorHandling
  
  def initialize(property, user_id, start_date, end_date, idempotency_key)
    @property = property
    @user_id = user_id
    @start_date = Date.parse(start_date.to_s)
    @end_date = Date.parse(end_date.to_s)
    @idempotency_key = idempotency_key
  end

  def call
    validate_input!
    check_idempotency!
    acquire_lock_and_create!
  end

  private

  attr_reader :property, :user_id, :start_date, :end_date, :idempotency_key

  def validate_input!
    BookingPolicy.validate_date_range(start_date, end_date)
  end

  def check_idempotency!
    existing_booking = Booking.find_by(idempotency_key: idempotency_key)
    if existing_booking
      Rails.logger.info "Idempotent request detected for key: #{idempotency_key}"
      throw :halt, existing_booking
    end
  end

  def acquire_lock_and_create!
    property.with_lock do
      # Double-check availability within lock
      unless available?
        raise PropertyUnavailableError, "Property is not available for the selected dates"
      end

      Booking.create!(
        property: property,
        user_id: user_id,
        start_date: start_date,
        end_date: end_date,
        idempotency_key: idempotency_key
      )
    end
  rescue ActiveRecord::RecordNotUnique
    raise DuplicateBookingError, "Duplicate booking detected"
  end

  def available?
    # Use exists? for better performance than none?
    !property.bookings.where(
      "start_date < ? AND end_date > ?", 
      end_date, 
      start_date
    ).exists?
  end
end

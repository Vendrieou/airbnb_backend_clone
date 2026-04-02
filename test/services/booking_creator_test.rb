require "test_helper"

class BookingCreatorTest < ActiveSupport::TestCase
  setup do
    @property = Property.create!(name: "Test Property", location: "Test Location")
    @user_id = 1
    @start_date = Date.today + 1.day
    @end_date = Date.today + 3.days
    @idempotency_key = "unique-key-123"
  end
  
  test "creates booking successfully" do
    creator = BookingCreator.new(@property, @user_id, @start_date, @end_date, @idempotency_key)
    booking = creator.call
    
    assert_not_nil booking
    assert_equal @property.id, booking.property_id
    assert_equal @user_id, booking.user_id
    assert_equal @start_date, booking.start_date
    assert_equal @end_date, booking.end_date
  end
  
  test "returns existing booking for duplicate idempotency key" do
    creator1 = BookingCreator.new(@property, @user_id, @start_date, @end_date, @idempotency_key)
    booking1 = creator1.call
    
    creator2 = BookingCreator.new(@property, @user_id, @start_date, @end_date, @idempotency_key)
    booking2 = creator2.call
    
    assert_equal booking1.id, booking2.id
  end
  
  test "raises error when property is unavailable" do
    # Create a booking that overlaps
    Booking.create!(
      property: @property,
      user_id: @user_id,
      start_date: @start_date,
      end_date: @end_date,
      idempotency_key: "initial-booking-key"
    )
    
    creator = BookingCreator.new(
      @property, 
      @user_id, 
      @start_date, 
      @end_date, 
      "another-key"
    )
    
    assert_raises(BookingCreator::PropertyUnavailableError) do
      creator.call
    end
  end
  
  test "raises error when end date is before start date" do
    creator = BookingCreator.new(
      @property, 
      @user_id, 
      @end_date, 
      @start_date, 
      "invalid-dates-key"
    )
    
    assert_raises(BookingCreator::InvalidDateRangeError) do
      creator.call
    end
  end
  
  test "raises error when start date is in the past" do
    past_date = Date.today - 5.days
    future_date = Date.today - 2.days
    
    creator = BookingCreator.new(
      @property, 
      @user_id, 
      past_date, 
      future_date, 
      "past-date-key"
    )
    
    assert_raises(BookingCreator::InvalidDateRangeError) do
      creator.call
    end
  end
end

require "test_helper"

class BookingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = Property.create!(name: "Test Property", location: "Test Location")
    @start_date = Date.today + 1.day
    @end_date = Date.today + 3.days
    @idempotency_key = "test-key-123"
  end
  
  test "should create booking with valid params" do
    post bookings_url, 
         params: { 
           property_id: @property.id, 
           start_date: @start_date, 
           end_date: @end_date 
         },
         headers: { 'Idempotency-Key' => @idempotency_key }
    
    assert_response :created
    assert_json_response_includes(message: "Booking created successfully")
  end
  
  test "should return error without idempotency key" do
    post bookings_url, 
         params: { 
           property_id: @property.id, 
           start_date: @start_date, 
           end_date: @end_date 
         }
    
    assert_response :bad_request
    assert_json_response_includes(error: "Idempotency-Key header is required")
  end
  
  test "should handle duplicate idempotency key" do
    # First request
    post bookings_url, 
         params: { 
           property_id: @property.id, 
           start_date: @start_date, 
           end_date: @end_date 
         },
         headers: { 'Idempotency-Key' => @idempotency_key }
    
    assert_response :created
    
    # Second request with same key
    post bookings_url, 
         params: { 
           property_id: @property.id, 
           start_date: @start_date, 
           end_date: @end_date 
         },
         headers: { 'Idempotency-Key' => @idempotency_key }
    
    assert_response :created
  end
  
  test "should return conflict when property unavailable" do
    # Block the dates with an existing booking
    Booking.create!(
      property: @property,
      user_id: 1,
      start_date: @start_date,
      end_date: @end_date,
      idempotency_key: "blocking-key"
    )
    
    post bookings_url, 
         params: { 
           property_id: @property.id, 
           start_date: @start_date, 
           end_date: @end_date 
         },
         headers: { 'Idempotency-Key' => "new-key" }
    
    assert_response :conflict
  end
  
  test "should return not found for invalid property" do
    post bookings_url, 
         params: { 
           property_id: 999_999, 
           start_date: @start_date, 
           end_date: @end_date 
         },
         headers: { 'Idempotency-Key' => @idempotency_key }
    
    assert_response :not_found
  end
  
  private
  
  def assert_json_response_includes(expected)
    response_data = JSON.parse(response.body)
    expected.each do |key, value|
      assert_equal value, response_data[key.to_s]
    end
  end
end

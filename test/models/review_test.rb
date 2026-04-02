require 'test_helper'

class ReviewTest < ActiveSupport::TestCase
  def setup
    @property = Property.create!(name: 'Test Property')
    @user = OpenStruct.new(id: 1)
    @host = OpenStruct.new(id: 2)
    
    @booking = Booking.create!(
      property: @property,
      user_id: @user.id,
      start_date: 5.days.ago,
      end_date: 2.days.ago,
      idempotency_key: 'test-booking-123'
    )
  end
  
  test 'should create review with valid data' do
    review = Review.new(
      property: @property,
      booking: @booking,
      guest_id: @user.id,
      host_id: @host.id,
      overall_rating: 5,
      cleanliness_rating: 5,
      accuracy_rating: 5,
      communication_rating: 5,
      location_rating: 4,
      check_in_rating: 5,
      value_rating: 5,
      comment: 'Amazing stay! Highly recommend this property.',
      is_guest_review: true,
      is_visible: true
    )
    
    assert review.save
    assert_equal 5, review.overall_rating
    assert_equal 'Amazing stay! Highly recommend this property.', review.comment
  end
  
  test 'should not allow rating outside 1-5 range' do
    review = Review.new(
      property: @property,
      booking: @booking,
      guest_id: @user.id,
      host_id: @host.id,
      overall_rating: 6,
      cleanliness_rating: 0,
      accuracy_rating: 5,
      communication_rating: 5,
      location_rating: 5,
      check_in_rating: 5,
      value_rating: 5,
      comment: 'Test comment',
      is_guest_review: true
    )
    
    assert_not review.valid?
    assert_includes review.errors[:overall_rating], 'must be included in 1..5'
    assert_includes review.errors[:cleanliness_rating], 'must be included in 1..5'
  end
  
  test 'should require minimum comment length' do
    review = Review.new(
      property: @property,
      booking: @booking,
      guest_id: @user.id,
      host_id: @host.id,
      overall_rating: 5,
      cleanliness_rating: 5,
      accuracy_rating: 5,
      communication_rating: 5,
      location_rating: 5,
      check_in_rating: 5,
      value_rating: 5,
      comment: 'Too short',
      is_guest_review: true
    )
    
    assert_not review.valid?
    assert_includes review.errors[:comment], 'is too short'
  end
  
  test 'should calculate overall rating from dimensions' do
    review = Review.new(
      property: @property,
      booking: @booking,
      guest_id: @user.id,
      host_id: @host.id,
      cleanliness_rating: 4,
      accuracy_rating: 5,
      communication_rating: 5,
      location_rating: 4,
      check_in_rating: 5,
      value_rating: 5,
      comment: 'Great experience overall',
      is_guest_review: true
    )
    
    assert_equal 4.67, review.calculated_overall
  end
  
  test 'should not allow review before checkout' do
    future_booking = Booking.create!(
      property: @property,
      user_id: @user.id,
      start_date: Date.today + 5.days,
      end_date: Date.today + 10.days,
      idempotency_key: 'future-booking-456'
    )
    
    review = Review.new(
      property: @property,
      booking: future_booking,
      guest_id: @user.id,
      host_id: @host.id,
      overall_rating: 5,
      cleanliness_rating: 5,
      accuracy_rating: 5,
      communication_rating: 5,
      location_rating: 5,
      check_in_rating: 5,
      value_rating: 5,
      comment: 'Premature review',
      is_guest_review: true
    )
    
    assert_not review.valid?
    assert_includes review.errors[:base], 'Reviews can only be submitted after checkout'
  end
  
  test 'should update property average rating on create' do
    assert_equal 0.0, @property.average_rating
    
    Review.create!(
      property: @property,
      booking: @booking,
      guest_id: @user.id,
      host_id: @host.id,
      overall_rating: 4,
      cleanliness_rating: 4,
      accuracy_rating: 4,
      communication_rating: 4,
      location_rating: 4,
      check_in_rating: 4,
      value_rating: 4,
      comment: 'Good stay',
      is_guest_review: true,
      is_visible: true
    )
    
    @property.reload
    assert_equal 4.0, @property.average_rating
    assert_equal 1, @property.review_count
  end
  
  test 'should flag review for moderation' do
    review = Review.create!(
      property: @property,
      booking: @booking,
      guest_id: @user.id,
      host_id: @host.id,
      overall_rating: 2,
      cleanliness_rating: 2,
      accuracy_rating: 2,
      communication_rating: 2,
      location_rating: 2,
      check_in_rating: 2,
      value_rating: 2,
      comment: 'Not as described',
      is_guest_review: true,
      is_visible: true
    )
    
    review.flag!('Inappropriate content')
    
    assert review.is_flagged?
    assert_not review.is_visible?
    assert_equal 'Inappropriate content', review.flag_reason
  end
  
  test 'should create host response to review' do
    guest_review = Review.create!(
      property: @property,
      booking: @booking,
      guest_id: @user.id,
      host_id: @host.id,
      overall_rating: 5,
      cleanliness_rating: 5,
      accuracy_rating: 5,
      communication_rating: 5,
      location_rating: 5,
      check_in_rating: 5,
      value_rating: 5,
      comment: 'Wonderful property!',
      is_guest_review: true,
      is_visible: true
    )
    
    guest_review.respond_by_host('Thank you for staying with us!')
    
    assert_equal 2, @property.reviews.count
    response = @property.reviews.where(is_response: true).first
    assert_equal 'Thank you for staying with us!', response.comment
    assert_equal guest_review.id, response.parent_review_id
  end
end

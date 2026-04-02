require 'test_helper'

class ReviewCreatorTest < ActiveSupport::TestCase
  def setup
    @property = Property.create!(name: 'Test Property')
    @user = OpenStruct.new(id: 1)
    @host = OpenStruct.new(id: 2)
    
    @completed_booking = Booking.create!(
      property: @property,
      user_id: @user.id,
      start_date: 5.days.ago,
      end_date: 2.days.ago,
      idempotency_key: 'completed-booking-123'
    )
    
    @future_booking = Booking.create!(
      property: @property,
      user_id: @user.id,
      start_date: Date.today + 5.days,
      end_date: Date.today + 10.days,
      idempotency_key: 'future-booking-456'
    )
    
    @valid_ratings = {
      cleanliness: 5,
      accuracy: 5,
      communication: 5,
      location: 4,
      check_in: 5,
      value: 5
    }
    
    @valid_comment = 'Amazing stay! The property was clean and exactly as described.'
  end
  
  test 'should create review successfully' do
    result = catch(:halt) do
      ReviewCreator.new(@completed_booking, @user.id, @valid_ratings, @valid_comment).call
    end
    
    assert result[:success]
    assert_not_nil result[:review]
    assert_equal 5, result[:review].overall_rating
    assert_equal @valid_comment, result[:review].comment
    assert @completed_booking.reload.guest_reviewed?
  end
  
  test 'should reject review for future booking' do
    result = catch(:halt) do
      ReviewCreator.new(@future_booking, @user.id, @valid_ratings, @valid_comment).call
    end
    
    assert_not result[:success]
    assert_equal 'Booking not completed yet', result[:error]
    assert_equal :unprocessable_entity, result[:status]
  end
  
  test 'should reject duplicate review' do
    # Create first review
    catch(:halt) do
      ReviewCreator.new(@completed_booking, @user.id, @valid_ratings, @valid_comment).call
    end
    
    # Try to create second review
    result = catch(:halt) do
      ReviewCreator.new(@completed_booking, @user.id, @valid_ratings, @valid_comment).call
    end
    
    assert_not result[:success]
    assert_equal 'Already reviewed', result[:error]
    assert_equal :conflict, result[:status]
  end
  
  test 'should reject invalid ratings (out of range)' do
    invalid_ratings = {
      cleanliness: 6,
      accuracy: 5,
      communication: 5,
      location: 4,
      check_in: 5,
      value: 5
    }
    
    result = catch(:halt) do
      ReviewCreator.new(@completed_booking, @user.id, invalid_ratings, @valid_comment).call
    end
    
    assert_not result[:success]
    assert_equal 'Invalid ratings', result[:error]
  end
  
  test 'should reject missing rating dimensions' do
    incomplete_ratings = {
      cleanliness: 5,
      accuracy: 5
      # Missing other dimensions
    }
    
    result = catch(:halt) do
      ReviewCreator.new(@completed_booking, @user.id, incomplete_ratings, @valid_comment).call
    end
    
    assert_not result[:success]
    assert_equal 'Invalid ratings', result[:error]
  end
  
  test 'should reject comment that is too short' do
    result = catch(:halt) do
      ReviewCreator.new(@completed_booking, @user.id, @valid_ratings, 'Too short').call
    end
    
    assert_not result[:success]
    assert_equal 'Comment too short or long', result[:error]
  end
  
  test 'should calculate overall rating if not provided' do
    result = catch(:halt) do
      ReviewCreator.new(@completed_booking, @user.id, @valid_ratings, @valid_comment).call
    end
    
    assert result[:success]
    # Average of [5,5,5,4,5,5] = 4.83, rounded to 5
    assert_equal 5, result[:review].overall_rating
  end
  
  test 'should update property average rating after review' do
    # First review - 4 stars
    ratings_4 = @valid_ratings.merge(cleanliness: 4, accuracy: 4, communication: 4, value: 4)
    catch(:halt) do
      ReviewCreator.new(@completed_booking, @user.id, ratings_4, @valid_comment).call
    end
    
    @property.reload
    assert_equal 4.0, @property.average_rating
    
    # Second review - 5 stars
    booking2 = Booking.create!(
      property: @property,
      user_id: @user.id,
      start_date: 10.days.ago,
      end_date: 7.days.ago,
      idempotency_key: 'booking-2nd-review'
    )
    
    catch(:halt) do
      ReviewCreator.new(booking2, @user.id, @valid_ratings, @valid_comment).call
    end
    
    @property.reload
    # Average of 4.0 and 5.0 = 4.5
    assert_equal 4.5, @property.average_rating
    assert_equal 2, @property.review_count
  end
end

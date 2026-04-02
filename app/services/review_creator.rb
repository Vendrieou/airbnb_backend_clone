class ReviewCreator
  attr_reader :booking, :user_id, :ratings, :comment, :is_guest_review
  
  def initialize(booking, user_id, ratings, comment, is_guest_review: true)
    @booking = booking
    @user_id = user_id
    @ratings = ratings
    @comment = comment
    @is_guest_review = is_guest_review
  end
  
  def call
    throw(:halt, { error: 'Booking not found', status: :not_found }) unless booking.present?
    throw(:halt, { error: 'Booking not completed yet', status: :unprocessable_entity }) unless booking_completed?
    throw(:halt, { error: 'Already reviewed', status: :conflict }) if already_reviewed?
    throw(:halt, { error: 'Invalid ratings', status: :unprocessable_entity }) unless valid_ratings?
    throw(:halt, { error: 'Comment too short or long', status: :unprocessable_entity }) unless valid_comment?
    
    ActiveRecord::Base.transaction do
      review = Review.create!(
        property: booking.property,
        booking: booking,
        guest_id: is_guest_review ? user_id : booking.property.user_id,
        host_id: is_guest_review ? booking.property.user_id : user_id,
        overall_rating: ratings[:overall] || calculate_overall,
        cleanliness_rating: ratings[:cleanliness],
        accuracy_rating: ratings[:accuracy],
        communication_rating: ratings[:communication],
        location_rating: ratings[:location],
        check_in_rating: ratings[:check_in],
        value_rating: ratings[:value],
        comment: comment,
        is_guest_review: is_guest_review,
        is_visible: true
      )
      
      # Mark booking as reviewed
      if is_guest_review
        booking.update!(guest_reviewed: true)
      else
        booking.update!(host_reviewed: true)
      end
      
      { success: true, review: review }
    end
  rescue ActiveRecord::RecordInvalid => e
    throw(:halt, { error: e.message, status: :unprocessable_entity })
  end
  
  private
  
  def booking_completed?
    booking.end_date < Date.today
  end
  
  def already_reviewed?
    if is_guest_review
      booking.guest_reviewed?
    else
      booking.host_reviewed?
    end
  end
  
  def valid_ratings?
    required_keys = [:cleanliness, :accuracy, :communication, :location, :check_in, :value]
    return false unless required_keys.all? { |key| ratings.key?(key) }
    
    ratings.values.all? { |v| v.is_a?(Integer) && v >= 1 && v <= 5 }
  end
  
  def valid_comment?
    comment.present? && comment.length >= 10 && comment.length <= 5000
  end
  
  def calculate_overall
    values = [
      ratings[:cleanliness],
      ratings[:accuracy],
      ratings[:communication],
      ratings[:location],
      ratings[:check_in],
      ratings[:value]
    ].compact
    
    return 5 if values.empty?
    (values.sum.to_f / values.size).round
  end
end

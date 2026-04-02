class Property < ApplicationRecord
  include BookingPolicy
  
  has_many :bookings, dependent: :destroy
  has_many :reviews, dependent: :destroy
  
  # Optimized availability check using exists? instead of none?
  def available?(check_in, check_out)
    !bookings.overlapping(check_in, check_out).exists?
  end
  
  # Method to get all bookings for a date range (useful for admin views)
  def bookings_in_range(start_date, end_date)
    bookings.where("start_date <= ? AND end_date >= ?", end_date, start_date)
  end
  
  # Get recent visible reviews
  def recent_reviews(limit = 5)
    reviews.visible.recent(limit)
  end
  
  # Check if property has good ratings (4+ stars)
  def highly_rated?
    average_rating && average_rating >= 4.0
  end
end

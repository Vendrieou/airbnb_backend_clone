class Property < ApplicationRecord
  include BookingPolicy
  
  has_many :bookings, dependent: :destroy
  
  # Optimized availability check using exists? instead of none?
  def available?(check_in, check_out)
    !bookings.overlapping(check_in, check_out).exists?
  end
  
  # Method to get all bookings for a date range (useful for admin views)
  def bookings_in_range(start_date, end_date)
    bookings.where("start_date <= ? AND end_date >= ?", end_date, start_date)
  end
end

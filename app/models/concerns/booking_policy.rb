module BookingPolicy
  extend ActiveSupport::Concern

  class_methods do
    def validate_date_range(start_date, end_date)
      raise InvalidDateRangeError, "End date must be after start date" if end_date <= start_date
      raise InvalidDateRangeError, "Start date cannot be in the past" if start_date < Date.today
    end
  end

  def available_for?(check_in, check_out)
    BookingPolicy.validate_date_range(check_in, check_out)
    
    # Check for overlapping bookings using efficient query
    overlaps = bookings.where(
      "start_date < ? AND end_date > ?", 
      check_out, 
      check_in
    ).exists?
    
    !overlaps
  rescue InvalidDateRangeError => e
    Rails.logger.warn "Invalid date range: #{e.message}"
    false
  end
end

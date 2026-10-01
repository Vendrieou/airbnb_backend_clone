module ErrorHandling
  extend ActiveSupport::Concern

  class BookingError < StandardError; end
  
  class PropertyUnavailableError < BookingError; end
  
  class DuplicateBookingError < BookingError; end
  
  class InvalidDateRangeError < BookingError; end

  # Raised when rental start/end dates don't align with the plan period
  # (e.g. weekly rentals must be multiples of 7 nights)
  class RentalPeriodMismatchError < BookingError; end
end

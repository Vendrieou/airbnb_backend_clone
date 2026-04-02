module ErrorHandling
  extend ActiveSupport::Concern

  class BookingError < StandardError; end
  
  class PropertyUnavailableError < BookingError; end
  
  class DuplicateBookingError < BookingError; end
  
  class InvalidDateRangeError < BookingError; end
end

class Booking < ApplicationRecord
  include ErrorHandling
  
  belongs_to :property

  validates :start_date, :end_date, :idempotency_key, presence: true
  validate :date_range_validity
  
  # Scope for finding overlapping bookings
  scope :overlapping, ->(start_date, end_date) { 
    where("start_date < ? AND end_date > ?", end_date, start_date) 
  }
  
  def self.create_safe_booking!(property, user_id, start_date, end_date, idempotency_key)
    creator = BookingCreator.new(property, user_id, start_date, end_date, idempotency_key)
    
    catch(:halt) do
      creator.call
    end
  end
  
  private
  
  def date_range_validity
    return if start_date.blank? || end_date.blank?
    
    if end_date <= start_date
      errors.add(:end_date, "must be after start date")
    end
    
    if start_date < Date.today
      errors.add(:start_date, "cannot be in the past")
    end
  end
end

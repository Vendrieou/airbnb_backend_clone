class Facility < ApplicationRecord
  belongs_to :property
  has_many :facility_bookings, dependent: :destroy
  has_many :facility_reviews, dependent: :destroy
  
  validates :name, :facility_type, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :duration_minutes, numericality: { greater_than: 0 }, if: -> { slot_interval_minutes.present? }
  
  scope :active, -> { where(active: true) }
  scope :by_type, ->(type) { where(facility_type: type) }
  scope :for_property, ->(property_id) { where(property_id: property_id) }
  scope :available_on_date, ->(date) { 
    joins(:facility_bookings)
      .where.not(facility_bookings: { status: 'cancelled' })
      .where(facility_bookings: { booking_date: date })
      .distinct
  }
  
  # Get available time slots for a specific date
  def available_slots(date)
    booked_times = facility_bookings
      .where(booking_date: date)
      .where.not(status: 'cancelled')
      .pluck(:start_time, :end_time)
    
    available_slots = []
    current_time = start_time || Time.new(0, 1, 1, 8, 0, 0) # Default 8 AM
    end_operating_time = end_time || Time.new(0, 1, 1, 20, 0, 0) # Default 8 PM
    
    while current_time + slot_interval_minutes.minutes <= end_operating_time
      slot_end = current_time + slot_interval_minutes.minutes
      
      # Check if this slot overlaps with any booked time
      is_available = booked_times.none? do |booked_start, booked_end|
        !(slot_end <= booked_start || current_time >= booked_end)
      end
      
      if is_available
        available_slots << {
          start_time: current_time.strftime('%H:%M'),
          end_time: slot_end.strftime('%H:%M')
        }
      end
      
      current_time += slot_interval_minutes.minutes
    end
    
    available_slots
  end
  
  # Calculate average rating
  def average_rating
    facility_reviews.visible.average(:rating)&.to_f&.round(2)
  end
  
  # Check if facility can be booked for a specific time slot
  def bookable?(date, start_time, quantity = 1)
    return false unless active?
    return false if quantity > max_capacity
    
    # Check availability
    slot_end = start_time.to_time + slot_interval_minutes.minutes
    overlapping = facility_bookings
      .where(booking_date: date)
      .where(start_time: start_time)
      .where.not(status: 'cancelled')
      .exists?
    
    !overlapping
  end
  
  # Get recent reviews
  def recent_reviews(limit = 5)
    facility_reviews.visible.order(created_at: :desc).limit(limit)
  end
end

class FacilityBooking < ApplicationRecord
  include ErrorHandling
  
  belongs_to :facility
  belongs_to :property
  belongs_to :guest, class_name: 'User', foreign_key: :user_id
  belongs_to :host, class_name: 'User', foreign_key: :host_id
  has_many :member_points, dependent: :destroy
  has_one :facility_review, class_name: 'FacilityReview', foreign_key: :facility_booking_id, dependent: :destroy
  
  validates :booking_date, :start_time, :end_time, :idempotency_key, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validate :date_not_in_past
  validate :time_range_validity
  validate :facility_availability, on: :create
  
  before_save :calculate_total_price
  
  scope :pending, -> { where(status: 'pending') }
  scope :confirmed, -> { where(status: 'confirmed') }
  scope :completed, -> { where(status: 'completed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :for_date, ->(date) { where(booking_date: date) }
  scope :upcoming, -> { where('booking_date >= ?', Date.today) }
  scope :past, -> { where('booking_date < ?', Date.today) }
  
  # Create facility booking safely with idempotency
  def self.create_safe_booking!(facility, property, user, host, booking_date, start_time, quantity, special_requests = nil, idempotency_key = nil)
    idempotency_key ||= SecureRandom.uuid
    
    # Check for existing booking with same idempotency key
    existing = find_by(idempotency_key: idempotency_key)
    return existing if existing.present?
    
    booking = new(
      facility: facility,
      property: property,
      guest: user,
      host: host,
      booking_date: booking_date,
      start_time: start_time,
      end_time: start_time.to_time + facility.slot_interval_minutes.minutes,
      quantity: quantity,
      price: facility.price,
      discount: calculate_discount(user, facility),
      discount_percent: calculate_discount_percent(user, facility),
      special_requests: special_requests,
      idempotency_key: idempotency_key,
      status: 'pending'
    )
    
    catch(:halt) do
      if booking.save
        booking
      else
        throw(:halt, booking)
      end
    end
  end
  
  # Confirm the booking (called by host or automatically)
  def confirm!
    update!(status: 'confirmed')
  end
  
  # Cancel the booking
  def cancel!
    update!(status: 'cancelled')
  end
  
  # Mark as completed (after the booking date has passed)
  def complete!
    update!(status: 'completed', used: true)
    award_points if can_award_points?
  end
  
  # Check if booking can be reviewed
  def can_be_reviewed?
    completed? && booking_date < Date.today && !facility_review
  end
  
  # Calculate and award points to guest
  def award_points
    points_earned = (total_price / 100).to_i # 1 point per $100 spent
    member_points.create!(
      points: points_earned,
      expires_at: 1.year.from_now
    )
    guest.increment!(:point, points_earned) if guest.respond_to?(:point)
  end
  
  private
  
  def date_not_in_past
    return if booking_date.blank?
    
    if booking_date < Date.today
      errors.add(:booking_date, "cannot be in the past")
    end
  end
  
  def time_range_validity
    return if start_time.blank? || end_time.blank?
    
    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
  
  def facility_availability
    return if booking_date.blank? || start_time.blank?
    
    if facility.present? && !facility.bookable?(booking_date, start_time, quantity)
      errors.add(:base, "Facility is not available for the selected time slot")
    end
  end
  
  def calculate_total_price
    subtotal = price * quantity
    discount_amount = subtotal * (discount_percent / 100.0) + discount
    self.total_price = subtotal - discount_amount
  end
  
  def self.calculate_discount(user, facility)
    # Implement member tier discounts here
    # For now, return 0
    0.0
  end
  
  def self.calculate_discount_percent(user, facility)
    # Implement member tier discount percentages
    # Example: Silver 10%, Gold 15%, Platinum 20%
    0.0
  end
  
  def can_award_points?
    !used || member_points.empty?
  end
end

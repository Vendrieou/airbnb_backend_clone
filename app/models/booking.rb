class Booking < ApplicationRecord
  include ErrorHandling
  
  belongs_to :property
  has_one :guest_review, class_name: 'Review', foreign_key: :booking_id, dependent: :destroy
  
  validates :start_date, :end_date, :idempotency_key, presence: true
  validate :date_range_validity
  
  # Scope for finding overlapping bookings
  scope :overlapping, ->(start_date, end_date) { 
    where("start_date < ? AND end_date > ?", end_date, start_date) 
  }
  
  # Scope for completed bookings (eligible for review)
  scope :completed, -> { where("end_date < ?", Date.today) }
  scope :pending_review, -> { where("end_date < ? AND guest_reviewed = ?", Date.today, false) }
  
  def self.create_safe_booking!(property, user_id, start_date, end_date, idempotency_key)
    creator = BookingCreator.new(property, user_id, start_date, end_date, idempotency_key)
    
    catch(:halt) do
      creator.call
    end
  end
  
  # Check if booking is eligible for review
  def can_be_reviewed_by_guest?
    end_date < Date.today && !guest_reviewed
  end
  
  # Check if host can still review
  def can_be_reviewed_by_host?
    end_date < Date.today && !host_reviewed
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

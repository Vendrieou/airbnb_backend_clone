class FacilityReview < ApplicationRecord
  belongs_to :facility
  belongs_to :facility_booking
  belongs_to :user
  
  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :facility_booking_id, uniqueness: { message: "has already been reviewed" }
  
  validate :booking_completed
  validate :booking_date_in_past
  
  scope :visible, -> { where(visible: true) }
  scope :recent, ->(limit = 5) { order(created_at: :desc).limit(limit) }
  scope :by_rating, ->(rating) { where(rating: rating) }
  
  # Create review safely
  def self.create_review!(facility_booking, user, rating, comment = nil)
    # Check if booking can be reviewed
    unless facility_booking.can_be_reviewed?
      throw(:halt, { error: "Booking cannot be reviewed yet" }) if block_given?
      return nil
    end
    
    review = new(
      facility: facility_booking.facility,
      facility_booking: facility_booking,
      user: user,
      rating: rating,
      comment: comment,
      visible: true
    )
    
    catch(:halt) do
      if review.save
        facility_booking.update!(guest_reviewed: true)
        review
      else
        throw(:halt, review)
      end
    end
  end
  
  # Host responds to review
  def host_respond!(response)
    update!(
      host_response: response,
      host_responded: true,
      host_response_at: Time.current
    )
  end
  
  private
  
  def booking_completed
    return if facility_booking.blank?
    
    unless facility_booking.completed? || facility_booking.used?
      errors.add(:base, "Can only review completed bookings")
    end
  end
  
  def booking_date_in_past
    return if facility_booking.blank?
    
    if facility_booking.booking_date >= Date.today
      errors.add(:base, "Can only review past bookings")
    end
  end
end

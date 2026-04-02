class Review < ApplicationRecord
  include ErrorHandling
  
  belongs_to :property, counter_cache: :review_count
  belongs_to :booking
  belongs_to :guest, class_name: 'User', optional: true
  belongs_to :host, class_name: 'User', optional: true
  belongs_to :parent_review, class_name: 'Review', optional: true
  has_many :replies, class_name: 'Review', foreign_key: :parent_review_id, dependent: :destroy
  
  # Rating validations (1-5 stars)
  validates :overall_rating, :cleanliness_rating, :accuracy_rating, 
           :communication_rating, :location_rating, :check_in_rating, 
           :value_rating, inclusion: { in: 1..5 }, numericality: { only_integer: true }
  
  validates :comment, presence: true, length: { minimum: 10, maximum: 5000 }
  
  validate :booking_completed
  validate :no_duplicate_review, on: :create
  validate :rating_consistency
  
  after_create :update_property_average_rating
  after_update :update_property_average_rating, if: :saved_change_to_is_visible?
  after_destroy :update_property_average_rating
  
  scope :visible, -> { where(is_visible: true) }
  scope :guest_reviews, -> { where(is_guest_review: true) }
  scope :host_responses, -> { where(is_response: true) }
  scope :flagged, -> { where(is_flagged: true) }
  scope :recent, ->(limit = 10) { order(created_at: :desc).limit(limit) }
  
  # Calculate average of all rating dimensions
  def calculated_overall
    ratings = [cleanliness_rating, accuracy_rating, communication_rating, 
               location_rating, check_in_rating, value_rating].compact
    return 0 if ratings.empty?
    (ratings.sum.to_f / ratings.size).round(2)
  end
  
  # Flag review for moderation
  def flag!(reason)
    update!(is_flagged: true, flagged_at: Time.current, flag_reason: reason, is_visible: false)
  end
  
  # Approve and publish review
  def approve!
    update!(is_visible: true, is_flagged: false, flagged_at: nil, flag_reason: nil)
  end
  
  # Create host response
  def respond_by_host(comment)
    transaction do
      Review.create!(
        property: property,
        booking: booking,
        guest_id: guest_id,
        host_id: host_id,
        overall_rating: overall_rating,
        cleanliness_rating: cleanliness_rating,
        accuracy_rating: accuracy_rating,
        communication_rating: communication_rating,
        location_rating: location_rating,
        check_in_rating: check_in_rating,
        value_rating: value_rating,
        comment: comment,
        is_guest_review: false,
        is_response: true,
        parent_review: self,
        is_visible: true
      )
    end
  end
  
  private
  
  def booking_completed
    return unless booking.present?
    
    if booking.end_date && booking.end_date > Date.today
      errors.add(:base, "Reviews can only be submitted after checkout")
    end
  end
  
  def no_duplicate_review
    return unless booking.present?
    
    existing_review = Review.where(
      booking: booking,
      is_guest_review: is_guest_review,
      is_response: false
    ).exists?
    
    if existing_review
      errors.add(:base, "#{is_guest_review ? 'Guest' : 'Host'} has already reviewed this booking")
    end
  end
  
  def rating_consistency
    return unless overall_rating.present?
    
    calculated = calculated_overall
    if (calculated - overall_rating).abs > 0.5
      errors.add(:overall_rating, "does not match calculated average from dimension ratings")
    end
  end
  
  def update_property_average_rating
    visible_reviews = property.reviews.visible
    
    if visible_reviews.exists?
      avg = visible_reviews.average(:overall_rating)&.to_f || 0.0
      property.update!(average_rating: avg.round(2), review_count: visible_reviews.count)
    else
      property.update!(average_rating: 0.0, review_count: 0)
    end
  end
end

class FacilityReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_facility_booking, only: [:create]
  
  def create
    @rating = params[:rating]&.to_i
    @comment = params[:comment]
    
    # Check if booking can be reviewed
    unless @facility_booking.can_be_reviewed?
      return render json: { error: "Booking cannot be reviewed yet" }, status: :unprocessable_entity
    end
    
    # Check if already reviewed
    if @facility_booking.facility_review.present?
      return render json: { error: "Booking has already been reviewed" }, status: :conflict
    end
    
    review = FacilityReview.create_review!(
      @facility_booking,
      current_user,
      @rating,
      @comment
    )
    
    if review
      render json: { 
        review: review,
        message: "Review submitted successfully",
        facility_rating: @facility_booking.facility.average_rating
      }, status: :created
    else
      render json: { error: "Failed to create review", details: review&.errors }, status: :unprocessable_entity
    end
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
  
  private
  
  def set_facility_booking
    @facility_booking = FacilityBooking.find(params[:facility_booking_id])
    
    # Ensure user owns the booking
    unless @facility_booking.user_id == current_user.id
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end

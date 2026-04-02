class ReviewsController < ApplicationController
  before_action :authenticate_user!
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ReviewError, with: :review_error
  
  # GET /properties/:property_id/reviews
  def index
    @property = Property.find(params[:property_id])
    @reviews = @property.reviews.visible.includes(:guest, :host).order(created_at: :desc)
    
    render json: {
      property: @property,
      reviews: @reviews,
      average_rating: @property.average_rating,
      review_count: @property.review_count
    }
  end
  
  # POST /bookings/:booking_id/reviews
  def create
    @booking = Booking.find(params[:booking_id])
    
    result = catch(:halt) do
      ReviewCreator.new(
        @booking,
        current_user.id,
        review_params[:ratings],
        review_params[:comment],
        is_guest_review: true
      ).call
    end
    
    if result[:success]
      @booking.update!(guest_reviewed: true)
      render json: { success: true, review: result[:review] }, status: :created
    else
      render json: { error: result[:error] }, status: result[:status] || :unprocessable_entity
    end
  end
  
  # PUT /reviews/:id
  def update
    @review = Review.find(params[:id])
    
    authorize_reviewer!
    
    if @review.update(review_params.except(:ratings))
      render json: { success: true, review: @review }
    else
      render json: { error: @review.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end
  
  # DELETE /reviews/:id (admin only)
  def destroy
    @review = Review.find(params[:id])
    
    # Only allow deletion if flagged or by admin
    unless @review.is_flagged? || current_user.admin?
      render json: { error: 'Cannot delete unflagged review' }, status: :forbidden
      return
    end
    
    @review.destroy
    head :no_content
  end
  
  # POST /reviews/:id/flag
  def flag
    @review = Review.find(params[:id])
    
    @review.flag!(flag_params[:reason])
    
    render json: { success: true, message: 'Review flagged for moderation' }
  end
  
  # POST /reviews/:id/approve (admin only)
  def approve
    @review = Review.find(params[:id])
    
    authorize_admin!
    
    @review.approve!
    
    render json: { success: true, review: @review }
  end
  
  # POST /reviews/:id/respond (host response)
  def respond
    @review = Review.find(params[:id])
    
    unless @review.host_id == current_user.id
      render json: { error: 'Unauthorized' }, status: :forbidden
      return
    end
    
    begin
      @review.respond_by_host(response_params[:comment])
      render json: { success: true, message: 'Response posted' }
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
  
  private
  
  def review_params
    params.require(:review).permit(:comment, ratings: [
      :overall, :cleanliness, :accuracy, :communication, 
      :location, :check_in, :value
    ])
  end
  
  def flag_params
    params.permit(:reason)
  end
  
  def response_params
    params.permit(:comment)
  end
  
  def authorize_reviewer!
    unless @review.guest_id == current_user.id || current_user.admin?
      render json: { error: 'Unauthorized' }, status: :forbidden
    end
  end
  
  def authorize_admin!
    unless current_user.admin?
      render json: { error: 'Admin access required' }, status: :forbidden
    end
  end
  
  def not_found
    render json: { error: 'Resource not found' }, status: :not_found
  end
  
  def review_error
    render json: { error: 'Review operation failed' }, status: :unprocessable_entity
  end
end

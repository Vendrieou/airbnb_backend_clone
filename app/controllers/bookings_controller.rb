class BookingsController < ApplicationController
  rescue_from BookingCreator::PropertyUnavailableError, with: :handle_unavailable
  rescue_from BookingCreator::DuplicateBookingError, with: :handle_duplicate
  rescue_from BookingCreator::InvalidDateRangeError, with: :handle_invalid_dates
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  
  def create
    idempotency_key = request.headers['Idempotency-Key']
    
    unless idempotency_key.present?
      return render json: { error: 'Idempotency-Key header is required' }, status: :bad_request
    end

    property = Property.find(params[:property_id])
    user_id = current_user_id # Delegate to authentication concern
    
    booking = Booking.create_safe_booking!(
      property,
      user_id,
      params[:start_date],
      params[:end_date],
      idempotency_key
    )

    # Publish domain event for side effects
    Events::BookingCreatedEvent.new(booking).publish

    render json: { 
      message: 'Booking created successfully', 
      booking: booking 
    }, status: :created
  end
  
  private
  
  def handle_unavailable(exception)
    render json: { error: exception.message }, status: :conflict
  end
  
  def handle_duplicate(exception)
    render json: { error: exception.message }, status: :conflict
  end
  
  def handle_invalid_dates(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end
  
  def handle_not_found(exception)
    render json: { error: 'Property not found' }, status: :not_found
  end
end

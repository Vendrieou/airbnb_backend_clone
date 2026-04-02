class FacilityBookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_facility, only: [:create]
  
  def create
    @booking_date = params[:booking_date]
    @start_time = params[:start_time]
    @quantity = params[:quantity]&.to_i || 1
    @special_requests = params[:special_requests]
    
    # Validate required parameters
    unless @booking_date.present? && @start_time.present?
      return render json: { error: "Booking date and start time are required" }, status: :unprocessable_entity
    end
    
    # Parse booking date
    begin
      booking_date = Date.parse(@booking_date)
    rescue ArgumentError
      return render json: { error: "Invalid booking date format" }, status: :unprocessable_entity
    end
    
    # Parse start time
    begin
      start_time = Time.parse(@start_time).strftime('%H:%M')
    rescue ArgumentError
      return render json: { error: "Invalid start time format" }, status: :unprocessable_entity
    end
    
    # Check if user is authorized
    if current_user.banned?
      return render json: { error: "Account is banned" }, status: :forbidden
    end
    
    # Create booking using service object
    creator = FacilityBookingCreator.new(
      @facility,
      @facility.property,
      current_user,
      @facility.property.host,
      booking_date,
      start_time,
      @quantity,
      @special_requests
    )
    
    result = catch(:halt) do
      creator.call
    end
    
    if result.is_a?(FacilityBooking)
      render json: { 
        booking: result,
        message: "Facility booking created successfully",
        next_steps: "Please wait for host confirmation"
      }, status: :created
    elsif result.is_a?(Hash) && result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: { error: "Failed to create booking", details: result&.errors }, status: :unprocessable_entity
    end
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
  
  def index
    @bookings = FacilityBooking.where(user_id: current_user.id)
      .includes(:facility, :property)
      .order(created_at: :desc)
    
    render json: { bookings: @bookings }
  end
  
  def show
    @booking = FacilityBooking.find(params[:id])
    
    # Ensure user owns the booking or is the host
    unless @booking.user_id == current_user.id || @booking.host_id == current_user.id
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end
    
    render json: { booking: @booking }
  end
  
  def cancel
    @booking = FacilityBooking.find(params[:id])
    
    # Ensure user owns the booking
    unless @booking.user_id == current_user.id
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end
    
    # Check if booking can be cancelled
    if @booking.status == 'completed' || @booking.status == 'cancelled'
      return render json: { error: "Cannot cancel this booking" }, status: :unprocessable_entity
    end
    
    if @booking.cancel!
      render json: { 
        booking: @booking,
        message: "Booking cancelled successfully"
      }
    else
      render json: { error: "Failed to cancel booking" }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_facility
    @facility = Facility.find(params[:facility_id])
    
    # Check if facility is active
    unless @facility.active?
      render json: { error: "Facility is not available" }, status: :not_found
    end
  end
end

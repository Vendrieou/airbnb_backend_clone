class FacilitiesController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show, :availability]
  
  def index
    @facilities = Facility.active
      .includes(:property, :reviews)
      .where(search_params)
    
    # Filter by date and time if provided
    if params[:date].present? && params[:time].present?
      @facilities = @facilities.available_on(Date.parse(params[:date]), params[:time])
    end
    
    # Filter by price range
    if params[:min_price].present?
      @facilities = @facilities.where('price >= ?', params[:min_price])
    end
    if params[:max_price].present?
      @facilities = @facilities.where('price <= ?', params[:max_price])
    end
    
    # Filter by facility type
    if params[:facility_type].present?
      @facilities = @facilities.where(facility_type: params[:facility_type])
    end
    
    # Sort options
    @facilities = case params[:sort]
                  when 'price_low' then @facilities.order(price: :asc)
                  when 'price_high' then @facilities.order(price: :desc)
                  when 'rating' then @facilities.includes(:reviews).order(Arel.sql('COALESCE(average_rating, 0) DESC'))
                  else @facilities.order(created_at: :desc)
                  end
    
    @facilities = @facilities.page(params[:page]).per(12)
  end

  def show
    @facility = Facility.includes(:property, :reviews, :host).find(params[:id])
    @available_slots = @facility.get_available_slots(params[:date], params[:quantity] || 1) if params[:date]
    @booking = @facility.bookings.build
  end
  
  # API endpoint for real-time availability checking
  def availability
    facility = Facility.find(params[:id])
    booking_date = params[:date] ? Date.parse(params[:date]) : Date.today
    quantity = params[:quantity] || 1
    
    available_slots = facility.get_available_slots(booking_date, quantity)
    
    render json: {
      facility_id: facility.id,
      date: booking_date,
      available_slots: available_slots,
      is_available: available_slots.any?
    }
  end

  private

  def search_params
    params.permit(:city, :property_id, :active)
  end
end

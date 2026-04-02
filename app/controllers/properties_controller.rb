class PropertiesController < ApplicationController
  before_action :authenticate_user!, only: [:create, :update, :destroy]
  before_action :set_property, only: [:show, :update, :destroy]

  def index
    @properties = Property.all
    
    # Apply filters
    @properties = @properties.available if params[:available] == 'true'
    
    # Geolocation search
    if params[:latitude].present? && params[:longitude].present?
      radius = (params[:radius_km] || 10).to_f
      @properties = @properties.search_by_location(
        params[:latitude].to_f, 
        params[:longitude].to_f, 
        radius
      )
    end
    
    # Price filter
    if params[:min_price].present?
      @properties = @properties.where('price_per_night >= ?', params[:min_price])
    end
    if params[:max_price].present?
      @properties = @properties.where('price_per_night <= ?', params[:max_price])
    end
    
    # Rating filter
    if params[:min_rating].present?
      @properties = @properties.where('average_rating >= ?', params[:min_rating])
    end
    
    @properties = @properties.includes(:reviews).page(params[:page]).per(20)
    
    render json: { properties: @properties }, status: :ok
  end

  def show
    render json: { property: @property }, status: :ok
  end

  def create
    @property = current_user.properties.build(property_params)
    
    if @property.save
      render json: { property: @property }, status: :created
    else
      render json: { errors: @property.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @property.update(property_params)
      render json: { property: @property }, status: :ok
    else
      render json: { errors: @property.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @property.destroy
    head :no_content
  end

  def nearby
    if @property.location.nil?
      render json: { errors: ["Location not available"] }, status: :not_found
      return
    end
    
    radius = (params[:radius_km] || 5).to_f
    @nearby_properties = Property
      .where.not(id: @property.id)
      .search_by_location(
        @property.latitude, 
        @property.longitude, 
        radius
      )
      .limit(10)
    
    render json: { properties: @nearby_properties }, status: :ok
  end

  private

  def set_property
    @property = Property.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ["Property not found"] }, status: :not_found
  end

  def property_params
    params.require(:property).permit(
      :name, :description, :price_per_night, :address, 
      :city, :state, :country, :postal_code,
      :latitude, :longitude, :available, :amenities
    )
  end
end

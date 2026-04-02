# Advanced Geolocation Search with PostGIS

## Overview
Implement location-based property search with radius filtering, map visualization, and spatial queries using PostgreSQL PostGIS extension.

## Prerequisites

### Install PostGIS
```bash
# Ubuntu/Debian
sudo apt-get install postgresql-14-postgis-3

# macOS with Homebrew
brew install postgis
```

### Enable PostGIS Extension
```ruby
class EnablePostgis < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'postgis'
  end
end
```

## Database Schema

### Migration: Add Geography Column to Properties
```ruby
class AddLocationToProperties < ActiveRecord::Migration[7.1]
  def change
    add_column :properties, :latitude, :decimal, precision: 9, scale: 6
    add_column :properties, :longitude, :decimal, precision: 9, scale: 6
    
    # Add PostGIS geography column for efficient spatial queries
    add_column :properties, :location, :st_point, geographic: true
    
    # Create spatial index
    add_index :properties, :location, using: :gist
    add_index :properties, [:latitude, :longitude]
    
    # Populate existing records (run after migration)
    Property.find_each do |property|
      if property.latitude.present? && property.longitude.present?
        property.update_column(:location, "POINT(#{property.longitude} #{property.latitude})")
      end
    end
  end
end
```

### Migration: Add Search Filters
```ruby
class AddSearchFiltersToProperties < ActiveRecord::Migration[7.1]
  def change
    add_column :properties, :neighborhood, :string
    add_column :properties, :city, :string
    add_column :properties, :state, :string
    add_column :properties, :country, :string
    add_column :properties, :zipcode, :string
    
    add_index :properties, :city
    add_index :properties, :state
    add_index :properties, :country
    add_index :properties, :neighborhood
  end
end
```

## Models

### app/models/property.rb
```ruby
class Property < ApplicationRecord
  # Spatial query methods
  acts_as_mappable
  
  validates :latitude, numericality: { 
    greater_than_or_equal_to: -90, 
    less_than_or_equal_to: 90, 
    allow_nil: true 
  }
  
  validates :longitude, numericality: { 
    greater_than_or_equal_to: -180, 
    less_than_or_equal_to: 180, 
    allow_nil: true 
  }
  
  validate :coordinates_consistency
  
  # Scopes for geolocation
  scope :near_location, ->(lat, lng, radius_in_miles = 10) {
    where(
      "ST_DWithin(location, ST_MakePoint(?, ?)::geography, ?)",
      lng, lat, radius_in_miles * 1609.34 # Convert miles to meters
    )
  }
  
  scope :within_bounds, ->(north, south, east, west) {
    where(
      "location && ST_MakeEnvelope(?, ?, ?, ?, 4326)",
      west, south, east, north
    )
  }
  
  scope :in_city, ->(city) { where(city: city) }
  scope :in_neighborhood, ->(neighborhood) { where(neighborhood: neighborhood) }
  
  # Class methods for advanced queries
  class << self
    def search_by_location(params)
      query = all
      
      # Location-based filtering
      if params[:latitude].present? && params[:longitude].present?
        radius = params[:radius].to_i || 10
        query = query.near_location(params[:latitude], params[:longitude], radius)
      end
      
      # Map bounds filtering (for map view)
      if params[:bounds].present?
        bounds = params[:bounds]
        query = query.within_bounds(
          bounds[:north], bounds[:south], bounds[:east], bounds[:west]
        )
      end
      
      # Text-based location filters
      query = query.in_city(params[:city]) if params[:city].present?
      query = query.in_neighborhood(params[:neighborhood]) if params[:neighborhood].present?
      
      # Additional filters
      query = apply_filters(query, params)
      
      query
    end
    
    def nearby_properties(lat, lng, radius = 10, limit = 20)
      near_location(lat, lng, radius)
        .select("*, ST_Distance(location, ST_MakePoint(#{lng}, #{lat})::geography) AS distance")
        .order("distance ASC")
        .limit(limit)
    end
    
    def properties_in_map_bounds(bounds, filters = {})
      within_bounds(bounds[:north], bounds[:south], bounds[:east], bounds[:west])
        .merge(apply_filters(all, filters))
    end
    
    def apply_filters(query, params)
      query = query.where(price_per_night: params[:min_price]..params[:max_price]) if params[:min_price].present? || params[:max_price].present?
      query = query.where(guests: params[:guests]..) if params[:guests].present?
      query = query.where(bedrooms: params[:bedrooms]..) if params[:bedrooms].present?
      query = query.where(bathrooms: params[:bathrooms]..) if params[:bathrooms].present?
      
      # Amenities filtering (assuming amenities is a jsonb column or separate table)
      if params[:amenities].present?
        amenities = Array(params[:amenities])
        amenities.each do |amenity|
          query = query.where("amenities @> ?", [amenity].to_json)
        end
      end
      
      # Property type
      query = query.where(property_type: params[:property_type]) if params[:property_type].present?
      
      # Instant book
      query = query.where(instant_book: true) if params[:instant_book] == 'true'
      
      # Availability (requires bookings association)
      if params[:check_in].present? && params[:check_out].present?
        query = query.available_between(params[:check_in], params[:check_out])
      end
      
      query
    end
    
    private
    
    def coordinates_consistency
      return unless latitude.present? && longitude.present?
      
      if latitude < -90 || latitude > 90
        errors.add(:latitude, 'must be between -90 and 90')
      end
      
      if longitude < -180 || longitude > 180
        errors.add(:longitude, 'must be between -180 and 180')
      end
    end
  end
  
  # Instance methods
  def distance_from(lat, lng)
    return nil unless location.present?
    
    Property.connection.select_value(
      "SELECT ST_Distance(location, ST_MakePoint(?, ?)::geography)",
      "Distance", [lng, lat]
    ).to_f
  end
  
  def distance_in_miles_from(lat, lng)
    distance = distance_from(lat, lng)
    distance ? (distance / 1609.34).round(2) : nil
  end
  
  def coordinates
    { latitude: latitude, longitude: longitude }
  end
end
```

### app/models/concerns/geocodable.rb
```ruby
module Geocodable
  extend ActiveSupport::Concern
  
  included do
    before_validation :geocode_address, if: :address_changed?
    after_save :update_location_column, if: :saved_change_to_latitude_or_longitude?
  end
  
  private
  
  def geocode_address
    return if skip_geocoding?
    
    result = Geocoder.search(full_address).first
    
    if result
      self.latitude = result.latitude
      self.longitude = result.longitude
    end
  end
  
  def update_location_column
    if latitude.present? && longitude.present?
      self.location = "POINT(#{longitude} #{latitude})"
      save!
    end
  end
  
  def full_address
    [street_address, city, state, country].compact.join(', ')
  end
  
  def address_changed?
    %i[street_address city state country].any? { |attr| send("#{attr}_changed?") }
  end
  
  def saved_change_to_latitude_or_longitude?
    saved_change_to_latitude? || saved_change_to_longitude?
  end
  
  def skip_geocoding?
    latitude.present? && longitude.present?
  end
end
```

## Services

### app/services/geocoding_service.rb
```ruby
class GeocodingService
  def initialize(address)
    @address = address
  end
  
  def self.geocode(address)
    new(address).geocode
  end
  
  def self.reverse_geocode(lat, lng)
    new(nil).reverse_geocode(lat, lng)
  end
  
  def geocode
    result = Geocoder.search(@address).first
    
    return nil unless result
    
    {
      latitude: result.latitude,
      longitude: result.longitude,
      address: result.address,
      city: result.city,
      state: result.state,
      country: result.country,
      zipcode: result.postal_code
    }
  end
  
  def reverse_geocode(lat, lng)
    result = Geocoder.coordinates([lat, lng]).first
    
    return nil unless result
    
    {
      address: result.address,
      city: result.city,
      state: result.state,
      country: result.country,
      zipcode: result.postal_code
    }
  end
end
```

### app/services/property_search_service.rb
```ruby
class PropertySearchService
  attr_reader :params, :current_user
  
  def initialize(params, current_user = nil)
    @params = params
    @current_user = current_user
  end
  
  def search
    @properties = Property.search_by_location(search_params)
    
    # Apply user-specific filters
    if @current_user
      @properties = @properties.merge(exclude_user_favorites) if params[:exclude_favorites]
    end
    
    # Pagination
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    
    @properties.page(page).per(per_page)
  end
  
  def search_results_with_metadata
    results = search
    
    {
      properties: results,
      total_count: results.total_count,
      page: results.current_page,
      per_page: results.per_page,
      total_pages: results.total_pages,
      bounds: calculate_bounds(results),
      center_point: calculate_center_point
    }
  end
  
  def nearby_properties(limit = 10)
    return [] unless params[:latitude].present? && params[:longitude].present?
    
    Property.nearby_properties(
      params[:latitude], 
      params[:longitude], 
      params[:radius] || 10,
      limit
    )
  end
  
  def map_markers
    search.map do |property|
      {
        id: property.id,
        latitude: property.latitude,
        longitude: property.longitude,
        price: property.price_per_night,
        name: property.name,
        image_url: property.images.first&.url,
        rating: property.average_rating,
        reviews_count: property.reviews_count
      }
    end
  end
  
  private
  
  def search_params
    params.permit(
      :latitude, :longitude, :radius, :city, :neighborhood,
      :min_price, :max_price, :guests, :bedrooms, :bathrooms,
      :property_type, :instant_book, :check_in, :check_out,
      amenities: [],
      bounds: [:north, :south, :east, :west]
    )
  end
  
  def calculate_bounds(results)
    return nil if results.empty?
    
    lats = results.pluck(:latitude).compact
    lngs = results.pluck(:longitude).compact
    
    return nil if lats.empty? || lngs.empty?
    
    {
      north: lats.max + 0.01,
      south: lats.min - 0.01,
      east: lngs.max + 0.01,
      west: lngs.min - 0.01
    }
  end
  
  def calculate_center_point
    if params[:latitude].present? && params[:longitude].present?
      return { 
        latitude: params[:latitude].to_f, 
        longitude: params[:longitude].to_f 
      }
    end
    
    # Default center (could be based on user's location or popular area)
    { latitude: 40.7128, longitude: -74.0060 } # NYC
  end
  
  def exclude_user_favorites
    favorite_property_ids = @current_user.wishlist_items.pluck(:property_id)
    Property.where.not(id: favorite_property_ids)
  end
end
```

## Controllers

### app/controllers/api/properties_controller.rb
```ruby
module Api
  class PropertiesController < ApplicationController
    before_action :authenticate_user!, only: [:create, :update, :destroy]
    
    def index
      search_service = PropertySearchService.new(search_params, current_user)
      
      if params[:map_view] == 'true'
        render json: {
          markers: search_service.map_markers,
          pagination: pagination_info(search_service.search)
        }
      else
        results = search_service.search_results_with_metadata
        render json: results
      end
    end
    
    def show
      @property = Property.find(params[:id])
      @nearby = Property.nearby_properties(
        @property.latitude, 
        @property.longitude, 
        5, 
        5
      )
      
      render json: {
        property: @property,
        nearby_properties: @nearby
      }
    end
    
    def nearby
      unless params[:latitude].present? && params[:longitude].present?
        return render json: { error: 'Latitude and longitude required' }, status: :bad_request
      end
      
      search_service = PropertySearchService.new(params, current_user)
      properties = search_service.nearby_properties(params[:limit] || 10)
      
      render json: properties
    end
    
    private
    
    def search_params
      params.permit(
        :latitude, :longitude, :radius, :city, :neighborhood, :country,
        :min_price, :max_price, :guests, :bedrooms, :bathrooms,
        :property_type, :instant_book, :check_in, :check_out,
        :page, :per_page, :map_view, :limit,
        amenities: [],
        bounds: [:north, :south, :east, :west]
      )
    end
    
    def pagination_info(scope)
      {
        current_page: scope.current_page,
        total_pages: scope.total_pages,
        total_count: scope.total_count,
        per_page: scope.per_page
      }
    end
  end
end
```

### app/controllers/api/geocoding_controller.rb
```ruby
module Api
  class GeocodingController < ApplicationController
    def search
      unless params[:query].present?
        return render json: { error: 'Query parameter required' }, status: :bad_request
      end
      
      results = Geocoder.search(params[:query]).first(5).map do |result|
        {
          address: result.address,
          latitude: result.latitude,
          longitude: result.longitude,
          city: result.city,
          state: result.state,
          country: result.country
        }
      end
      
      render json: { suggestions: results }
    end
    
    def reverse
      unless params[:latitude].present? && params[:longitude].present?
        return render json: { error: 'Latitude and longitude required' }, status: :bad_request
      end
      
      result = Geocoder.coordinates([params[:latitude], params[:longitude]]).first
      
      if result
        render json: {
          address: result.address,
          city: result.city,
          state: result.state,
          country: result.country,
          zipcode: result.postal_code
        }
      else
        render json: { error: 'No address found' }, status: :not_found
      end
    end
  end
end
```

## Routes

### config/routes.rb
```ruby
Rails.application.routes.draw do
  namespace :api do
    resources :properties do
      collection do
        get :nearby
      end
    end
    
    resources :geocoding, only: [] do
      collection do
        get :search
        get :reverse
      end
    end
  end
end
```

## Frontend Integration (React with Mapbox)

### app/javascript/components/PropertyMap.jsx
```jsx
import React, { useState, useEffect, useRef } from 'react'
import mapboxgl from 'mapbox-gl'

mapboxgl.accessToken = process.env.REACT_APP_MAPBOX_TOKEN

const PropertyMap = ({ 
  properties, 
  center, 
  zoom = 12, 
  onMarkerClick,
  onMapMove 
}) => {
  const mapContainerRef = useRef(null)
  const mapRef = useRef(null)
  const markersRef = useRef([])
  
  const [selectedProperty, setSelectedProperty] = useState(null)

  useEffect(() => {
    // Initialize map
    mapRef.current = new mapboxgl.Map({
      container: mapContainerRef.current,
      style: 'mapbox://styles/mapbox/streets-v11',
      center: [center.longitude, center.latitude],
      zoom: zoom
    })

    // Add navigation controls
    mapRef.current.addControl(new mapboxgl.NavigationControl())

    // Handle map move events
    mapRef.current.on('moveend', () => {
      const bounds = mapRef.current.getBounds()
      if (onMapMove) {
        onMapMove({
          north: bounds.getNorthEast().lat,
          south: bounds.getSouthWest().lat,
          east: bounds.getNorthEast().lng,
          west: bounds.getSouthWest().lng,
          center: mapRef.current.getCenter(),
          zoom: mapRef.current.getZoom()
        })
      }
    })

    return () => mapRef.current.remove()
  }, [])

  // Update markers when properties change
  useEffect(() => {
    if (!mapRef.current) return

    // Clear existing markers
    markersRef.current.forEach(marker => marker.remove())
    markersRef.current = []

    // Add new markers
    properties.forEach(property => {
      const el = document.createElement('div')
      el.className = 'marker'
      el.innerHTML = `
        <div class="price-tag">$${property.price}</div>
      `
      
      el.addEventListener('click', () => {
        setSelectedProperty(property)
        if (onMarkerClick) {
          onMarkerClick(property)
        }
      })

      const marker = new mapboxgl.Marker(el)
        .setLngLat([property.longitude, property.latitude])
        .addTo(mapRef.current)

      markersRef.current.push(marker)
    })
  }, [properties])

  // Fly to selected property
  useEffect(() => {
    if (selectedProperty && mapRef.current) {
      mapRef.current.flyTo({
        center: [selectedProperty.longitude, selectedProperty.latitude],
        zoom: 15,
        essential: true
      })
    }
  }, [selectedProperty])

  return (
    <div className="property-map-container">
      <div ref={mapContainerRef} className="map-container" />
      {selectedProperty && (
        <div className="property-popup">
          <img src={selectedProperty.image_url} alt={selectedProperty.name} />
          <h3>{selectedProperty.name}</h3>
          <p>${selectedProperty.price}/night</p>
          <p>⭐ {selectedProperty.rating} ({selectedProperty.reviews_count} reviews)</p>
        </div>
      )}
    </div>
  )
}

export default PropertyMap
```

### app/javascript/components/SearchPage.jsx
```jsx
import React, { useState, useEffect } from 'react'
import PropertyMap from './PropertyMap'
import PropertyList from './PropertyList'
import SearchFilters from './SearchFilters'

const SearchPage = ({ initialLocation }) => {
  const [properties, setProperties] = useState([])
  const [filters, setFilters] = useState({
    latitude: initialLocation?.latitude,
    longitude: initialLocation?.longitude,
    radius: 10
  })
  const [mapBounds, setMapBounds] = useState(null)
  const [viewMode, setViewMode] = useState('split') // 'map', 'list', 'split'
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    fetchProperties()
  }, [filters, mapBounds])

  const fetchProperties = async () => {
    setLoading(true)
    
    const params = new URLSearchParams({
      ...filters,
      map_view: 'true',
      ...(mapBounds && { bounds: JSON.stringify(mapBounds) })
    })

    try {
      const response = await fetch(`/api/properties?${params}`)
      const data = await response.json()
      setProperties(data.markers || data.properties || [])
    } catch (error) {
      console.error('Failed to fetch properties:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleMapMove = (bounds) => {
    setMapBounds({
      north: bounds.north,
      south: bounds.south,
      east: bounds.east,
      west: bounds.west
    })
    setFilters(prev => ({
      ...prev,
      latitude: bounds.center.lat,
      longitude: bounds.center.lng
    }))
  }

  const handleFilterChange = (newFilters) => {
    setFilters(prev => ({ ...prev, ...newFilters }))
  }

  const handleMarkerClick = (property) => {
    // Navigate to property detail or show popup
    window.location.href = `/properties/${property.id}`
  }

  return (
    <div className={`search-page view-${viewMode}`}>
      <SearchFilters 
        filters={filters} 
        onChange={handleFilterChange}
        onSubmit={fetchProperties}
      />
      
      <div className="search-results">
        {(viewMode === 'list' || viewMode === 'split') && (
          <PropertyList 
            properties={properties} 
            loading={loading}
          />
        )}
        
        {(viewMode === 'map' || viewMode === 'split') && (
          <PropertyMap
            properties={properties}
            center={{ 
              latitude: filters.latitude || 40.7128, 
              longitude: filters.longitude || -74.0060 
            }}
            onMarkerClick={handleMarkerClick}
            onMapMove={handleMapMove}
          />
        )}
      </div>
      
      <div className="view-toggle">
        <button 
          className={viewMode === 'list' ? 'active' : ''}
          onClick={() => setViewMode('list')}
        >
          List
        </button>
        <button 
          className={viewMode === 'split' ? 'active' : ''}
          onClick={() => setViewMode('split')}
        >
          Split
        </button>
        <button 
          className={viewMode === 'map' ? 'active' : ''}
          onClick={() => setViewMode('map')}
        >
          Map
        </button>
      </div>
    </div>
  )
}

export default SearchPage
```

## Configuration

### config/initializers/geocoder.rb
```ruby
Geocoder.configure(
  lookup: :google, # or :nominatim, :mapbox
  
  api_key: ENV['GOOGLE_MAPS_API_KEY'],
  
  timeout: 5,
  
  units: :mi,
  
  cache: Redis.new,
  cache_prefix: 'geocoder:'
)
```

### config/initializers/rgeo.rb
```ruby
# RGeo configuration for PostGIS
RGeo::Geographic.project_factory = lambda do |srid|
  RGeo::Geographic.projected_coordinate_system(srid)
end
```

## Testing

### test/services/property_search_service_test.rb
```ruby
require 'test_helper'

class PropertySearchServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @property = properties(:one)
    @params = {
      latitude: 40.7128,
      longitude: -74.0060,
      radius: 10
    }
  end

  test 'search returns properties within radius' do
    service = PropertySearchService.new(@params, @user)
    results = service.search

    assert results.any?
    results.each do |property|
      distance = property.distance_in_miles_from(@params[:latitude], @params[:longitude])
      assert distance <= @params[:radius]
    end
  end

  test 'search respects price filters' do
    @params[:min_price] = 100
    @params[:max_price] = 200
    
    service = PropertySearchService.new(@params, @user)
    results = service.search

    results.each do |property|
      assert property.price_per_night >= 100
      assert property.price_per_night <= 200
    end
  end

  test 'map markers returns correct format' do
    service = PropertySearchService.new(@params, @user)
    markers = service.map_markers

    assert markers.any?
    marker = markers.first
    
    assert marker.key?(:id)
    assert marker.key?(:latitude)
    assert marker.key?(:longitude)
    assert marker.key?(:price)
  end

  test 'nearby properties returns sorted by distance' do
    service = PropertySearchService.new(@params, @user)
    nearby = service.nearby_properties(5)

    assert nearby.size <= 5
    
    distances = nearby.map do |p|
      p.distance_in_miles_from(@params[:latitude], @params[:longitude])
    end
    
    assert_equal distances.sort, distances
  end
end
```

## Deployment Checklist

- [ ] Install PostgreSQL PostGIS extension
- [ ] Enable PostGIS in database
- [ ] Add latitude/longitude/location columns to properties
- [ ] Create spatial indexes
- [ ] Configure Geocoder gem
- [ ] Set up Mapbox/Google Maps API keys
- [ ] Deploy frontend map components
- [ ] Test spatial queries with large datasets
- [ ] Monitor query performance

## Performance Optimization

### Add Composite Indexes
```ruby
class AddPropertySearchIndexes < ActiveRecord::Migration[7.1]
  def change
    add_index :properties, [:city, :price_per_night]
    add_index :properties, [:property_type, :guests]
    add_index :properties, [:instant_book, :location], using: :gist
  end
end
```

### Use Materialized Views for Complex Queries
```ruby
class CreatePropertySearchView < ActiveRecord::Migration[7.1]
  def change
    execute <<-SQL
      CREATE MATERIALIZED VIEW property_search_index AS
      SELECT 
        p.id,
        p.name,
        p.price_per_night,
        p.guests,
        p.bedrooms,
        p.bathrooms,
        p.property_type,
        p.latitude,
        p.longitude,
        p.location,
        AVG(r.rating) as average_rating,
        COUNT(r.id) as reviews_count,
        p.instant_book
      FROM properties p
      LEFT JOIN reviews r ON p.id = r.property_id
      WHERE p.status = 'active'
      GROUP BY p.id;
      
      CREATE INDEX idx_property_search_location ON property_search_index USING gist(location);
      CREATE INDEX idx_property_search_price ON property_search_index(price_per_night);
      CREATE INDEX idx_property_search_rating ON property_search_index(average_rating DESC);
    SQL
    
    add_index :property_search_index, :instant_book
  end
end
```

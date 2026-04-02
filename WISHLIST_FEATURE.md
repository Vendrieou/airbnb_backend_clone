# Wishlist/Favorites System

## Overview
Allow users to save properties to customizable wishlists, share lists with others, and receive notifications for price drops and availability.

## Database Schema

### Migration: Create Wishlists
```ruby
class CreateWishlists < ActiveRecord::Migration[7.1]
  def change
    create_table :wishlists do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.boolean :public, default: false
      t.boolean :collaborative, default: false
      t.string :share_token
      t.datetime :shared_at
      
      t.timestamps
    end
    
    add_index :wishlists, :share_token, unique: true
    add_index :wishlists, [:user_id, :name], unique: true
  end
end
```

### Migration: Create Wishlist Items
```ruby
class CreateWishlistItems < ActiveRecord::Migration[7.1]
  def change
    create_table :wishlist_items do |t|
      t.references :wishlist, null: false, foreign_key: true
      t.references :property, null: false, foreign_key: true
      t.integer :position
      t.text :notes
      
      t.timestamps
    end
    
    add_index :wishlist_items, [:wishlist_id, :property_id], unique: true
    add_index :wishlist_items, :position
    add_index :wishlist_items, [:property_id, :created_at]
  end
end
```

### Migration: Add Price Tracking
```ruby
class AddPriceTrackingToWishlistItems < ActiveRecord::Migration[7.1]
  def change
    add_column :wishlist_items, :saved_price_cents, :integer
    add_column :wishlist_items, :price_drop_alert, :boolean, default: true
    add_column :wishlist_items, :availability_alert, :boolean, default: true
    add_column :wishlist_items, :last_checked_at, :datetime
    
    add_index :wishlist_items, :price_drop_alert
    add_index :wishlist_items, :availability_alert
  end
end
```

## Models

### app/models/wishlist.rb
```ruby
class Wishlist < ApplicationRecord
  belongs_to :user
  has_many :wishlist_items, -> { order(position: :asc) }, dependent: :destroy
  has_many :properties, through: :wishlist_items
  has_many :collaborators, class_name: 'WishlistCollaborator', dependent: :destroy
  has_many :users, through: :collaborators
  
  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :user_id }
  validates :description, length: { maximum: 500 }
  
  before_validation :generate_share_token, if: :will_save_change_to_public?
  
  scope :public_wishlists, -> { where(public: true) }
  scope :for_user, ->(user) { where(user_id: user.id) }
  scope :with_properties, -> { includes(:properties) }
  
  def self.find_by_share_token(token)
    find_by(share_token: token)
  end
  
  def add_property(property, notes: nil)
    item = wishlist_items.find_or_initialize_by(property: property)
    item.notes = notes if notes.present?
    item.saved_price_cents = property.price_per_night.cents
    item.position = (wishlist_items.maximum(:position) || 0) + 1
    item.save!
    item
  end
  
  def remove_property(property)
    wishlist_items.find_by(property: property)&.destroy
  end
  
  def has_property?(property)
    wishlist_items.exists?(property: property)
  end
  
  def property_count
    wishlist_items.count
  end
  
  def lowest_price
    properties.minimum(:price_per_night)
  end
  
  def average_price
    properties.average(:price_per_night)
  end
  
  def share_url
    return nil unless public? && share_token.present?
    
    Rails.application.routes.url_helpers.shared_wishlist_url(share_token)
  end
  
  def notify_price_drops
    return unless public?
    
    wishlist_items.each do |item|
      next unless item.price_drop_alert?
      next unless item.saved_price_cents && item.property.price_per_night.cents < item.saved_price_cents
      
      PriceDropMailer.with(
        wishlist: self,
        property: item.property,
        old_price: item.saved_price_cents,
        new_price: item.property.price_per_night.cents
      ).price_drop_email.deliver_later
      
      item.update(saved_price_cents: item.property.price_per_night.cents)
    end
  end
  
  private
  
  def generate_share_token
    self.share_token = SecureRandom.uuid if public? && !share_token.present?
  end
end
```

### app/models/wishlist_item.rb
```ruby
class WishlistItem < ApplicationRecord
  belongs_to :wishlist
  belongs_to :property
  
  validates :property_id, uniqueness: { scope: :wishlist_id }
  
  scope :with_price_drops, -> {
    joins(:property)
      .where('wishlist_items.saved_price_cents IS NOT NULL')
      .where('properties.price_per_night_cents < wishlist_items.saved_price_cents')
  }
  
  scope :available, -> {
    joins(:property)
      .where(properties: { status: 'active' })
  }
  
  def price_dropped?
    return false unless saved_price_cents.present?
    
    property.price_per_night.cents < saved_price_cents
  end
  
  def price_drop_amount
    return 0 unless price_dropped?
    
    saved_price_cents - property.price_per_night.cents
  end
  
  def price_drop_percentage
    return 0 unless price_dropped? && saved_price_cents > 0
    
    ((price_drop_amount / saved_price_cents.to_f) * 100).round(2)
  end
  
  def check_availability(dates = nil)
    return false unless availability_alert?
    
    dates ||= [Date.today, Date.today + 30.days]
    
    property.available_between?(dates[0], dates[1])
  end
end
```

### app/models/wishlist_collaborator.rb
```ruby
class WishlistCollaborator < ApplicationRecord
  belongs_to :wishlist
  belongs_to :user
  
  validates :user_id, uniqueness: { scope: :wishlist_id }
  validates :email, presence: true, if: :user_id_blank?
  
  enum role: { viewer: 0, editor: 1 }
  
  scope :editors, -> { where(role: :editor) }
  scope :viewers, -> { where(role: :viewer) }
  
  private
  
  def user_id_blank?
    user_id.blank?
  end
end
```

## Services

### app/services/wishlist_service.rb
```ruby
class WishlistService
  attr_reader :user
  
  def initialize(user)
    @user = user
  end
  
  def self.for_user(user)
    new(user)
  end
  
  def create_wishlist(name:, description: nil, public: false, collaborative: false)
    wishlist = user.wishlists.build(
      name: name,
      description: description,
      public: public,
      collaborative: collaborative
    )
    
    if wishlist.save
      wishlist
    else
      raise ArgumentError, wishlist.errors.full_messages.join(', ')
    end
  end
  
  def add_to_wishlist(wishlist_id, property_id, notes: nil)
    wishlist = user.wishlists.find(wishlist_id)
    property = Property.find(property_id)
    
    item = wishlist.add_property(property, notes: notes)
    
    # Send notification if property was added by collaborator
    if current_user != wishlist.user
      WishlistNotificationMailer.with(
        wishlist: wishlist,
        property: property,
        added_by: current_user
      ).property_added_email.deliver_later
    end
    
    item
  end
  
  def remove_from_wishlist(wishlist_id, property_id)
    wishlist = user.wishlists.find(wishlist_id)
    wishlist.remove_property(Property.find(property_id))
  end
  
  def toggle_favorite(property_id)
    property = Property.find(property_id)
    
    existing = user.wishlists.joins(:wishlist_items)
                       .find_by(wishlist_items: { property_id: property_id })
    
    if existing
      remove_from_wishlist(existing.id, property_id)
      { favorited: false, wishlist: existing }
    else
      # Add to default wishlist or create one
      default_wishlist = user.wishlists.find_or_create_by!(name: 'Favorites')
      item = add_to_wishlist(default_wishlist.id, property_id)
      { favorited: true, wishlist: default_wishlist, item: item }
    end
  end
  
  def move_item(item_id, position)
    item = WishlistItem.find(item_id)
    
    # Ensure user has access
    unless item.wishlist.user_id == user.id || 
           item.wishlist.collaborators.exists?(user: user, role: :editor)
      raise ActiveRecord::RecordNotFound
    end
    
    item.update!(position: position)
    
    # Reorder other items
    reorder_items(item.wishlist, item.position, item_id)
    
    item
  end
  
  def share_wishlist(wishlist_id, emails:, role: :viewer)
    wishlist = user.wishlists.find(wishlist_id)
    wishlist.update!(public: true)
    
    emails.each do |email|
      collaborator = wishlist.collaborators.find_or_initialize_by(email: email)
      collaborator.role = role
      collaborator.save!
      
      WishlistShareMailer.with(
        wishlist: wishlist,
        recipient_email: email,
        sender: user
      ).invitation_email.deliver_later
    end
    
    wishlist
  end
  
  def get_recommendations(wishlist)
    # Get properties similar to those in the wishlist
    property_ids = wishlist.properties.pluck(:id)
    
    Property.where.not(id: property_ids)
            .where(city: wishlist.properties.pluck(:city).uniq)
            .or(Property.where(property_type: wishlist.properties.pluck(:property_type).uniq))
            .limit(10)
  end
  
  private
  
  def reorder_items(wishlist, position, exclude_id)
    wishlist.wishlist_items.where.not(id: exclude_id)
           .where('position >= ?', position)
           .each_with_index do |item, index|
      item.update_column(:position, position + index + 1)
    end
  end
end
```

### app/services/price_alert_service.rb
```ruby
class PriceAlertService
  def self.check_all_price_drops
    Wishlist.public_wishlists.find_each do |wishlist|
      wishlist.notify_price_drops
    end
  end
  
  def self.check_availability_alerts
    WishlistItem.where(availability_alert: true).find_each do |item|
      next unless item.check_availability
      
      AvailabilityAlertMailer.with(
        wishlist_item: item,
        property: item.property
      ).available_email.deliver_later
    end
  end
end
```

## Controllers

### app/controllers/api/wishlists_controller.rb
```ruby
module Api
  class WishlistsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_wishlist, only: [:show, :update, :destroy, :add_property, :remove_property]
    
    def index
      @wishlists = current_user.wishlists.includes(:properties, :wishlist_items)
      render json: @wishlists, each_serializer: WishlistSerializer
    end
    
    def show
      render json: @wishlist, serializer: WishlistDetailSerializer
    end
    
    def create
      @wishlist = current_user.wishlists.build(wishlist_params)
      
      if @wishlist.save
        render json: @wishlist, serializer: WishlistSerializer, status: :created
      else
        render json: { errors: @wishlist.errors.full_messages }, status: :unprocessable_entity
      end
    end
    
    def update
      if @wishlist.update(wishlist_params)
        render json: @wishlist, serializer: WishlistSerializer
      else
        render json: { errors: @wishlist.errors.full_messages }, status: :unprocessable_entity
      end
    end
    
    def destroy
      @wishlist.destroy
      head :no_content
    end
    
    def add_property
      authorize! :edit, @wishlist
      
      @item = @wishlist.wishlist_items.create!(
        property_id: params[:property_id],
        notes: params[:notes]
      )
      
      render json: @item, status: :created
    end
    
    def remove_property
      authorize! :edit, @wishlist
      
      @wishlist.wishlist_items.find_by(property_id: params[:property_id])&.destroy
      
      head :no_content
    end
    
    def share
      authorize! :share, @wishlist
      
      WishlistService.new(current_user).share_wishlist(
        @wishlist.id,
        emails: params[:emails],
        role: params[:role] || :viewer
      )
      
      render json: { message: 'Invitations sent', share_url: @wishlist.share_url }
    end
    
    private
    
    def set_wishlist
      @wishlist = current_user.wishlists.find(params[:id])
    end
    
    def wishlist_params
      params.require(:wishlist).permit(:name, :description, :public, :collaborative)
    end
    
    def authorize!
      unless @wishlist.user_id == current_user.id || 
             @wishlist.collaborators.exists?(user: current_user, role: :editor)
        render json: { error: 'Unauthorized' }, status: :forbidden
      end
    end
  end
end
```

### app/controllers/api/favorites_controller.rb
```ruby
module Api
  class FavoritesController < ApplicationController
    before_action :authenticate_user!
    
    def toggle
      result = WishlistService.new(current_user).toggle_favorite(params[:property_id])
      
      render json: {
        favorited: result[:favorited],
        wishlist_id: result[:wishlist]&.id,
        wishlist_name: result[:wishlist]&.name
      }
    end
    
    def index
      @properties = current_user.wishlists.joins(:properties).distinct
      render json: @properties, each_serializer: PropertySerializer
    end
    
    def is_favorite
      property = Property.find(params[:property_id])
      
      is_favorite = current_user.wishlists.joins(:wishlist_items)
                         .exists?(wishlist_items: { property_id: property.id })
      
      render json: { favorite: is_favorite }
    end
  end
end
```

### app/controllers/shared/wishlists_controller.rb
```ruby
module Shared
  class WishlistsController < ApplicationController
    def show
      @wishlist = Wishlist.find_by_share_token(params[:token])
      
      unless @wishlist&.public?
        return render json: { error: 'Wishlist not found or private' }, status: :not_found
      end
      
      render json: @wishlist, serializer: SharedWishlistSerializer
    end
    
    def add_property
      @wishlist = Wishlist.find_by_share_token(params[:token])
      
      unless @wishlist&.public? && @wishlist.collaborative?
        return render json: { error: 'Cannot add to this wishlist' }, status: :forbidden
      end
      
      @item = @wishlist.wishlist_items.create!(property_id: params[:property_id])
      
      render json: @item, status: :created
    end
  end
end
```

## Serializers

### app/serializers/wishlist_serializer.rb
```ruby
class WishlistSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :public, :property_count, :lowest_price, :share_url
  
  def property_count
    object.property_count
  end
  
  def lowest_price
    object.lowest_price
  end
  
  def share_url
    object.share_url
  end
end
```

### app/serializers/wishlist_detail_serializer.rb
```ruby
class WishlistDetailSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :public, :collaborative, 
             :property_count, :average_price, :share_url, :created_at
  
  has_many :properties, serializer: PropertyPreviewSerializer
  has_many :wishlist_items
  
  def property_count
    object.property_count
  end
  
  def average_price
    object.average_price
  end
  
  def share_url
    object.share_url
  end
end
```

### app/serializers/wishlist_item_serializer.rb
```ruby
class WishlistItemSerializer < ActiveModel::Serializer
  attributes :id, :property_id, :notes, :saved_price_cents, 
             :price_dropped?, :price_drop_amount, :price_drop_percentage,
             :created_at
  
  has_one :property, serializer: PropertyPreviewSerializer
  
  def price_dropped?
    object.price_dropped?
  end
  
  def price_drop_amount
    object.price_drop_amount
  end
  
  def price_drop_percentage
    object.price_drop_percentage
  end
end
```

## Routes

### config/routes.rb
```ruby
Rails.application.routes.draw do
  namespace :api do
    resources :wishlists do
      post :add_property
      delete :remove_property
      post :share
    end
    
    resources :favorites, only: [] do
      collection do
        post :toggle
        get :index
        get :is_favorite
      end
    end
  end
  
  namespace :shared do
    get 'wishlists/:token', to: 'wishlists#show', as: :wishlist
    post 'wishlists/:token/add', to: 'wishlists#add_property'
  end
end
```

## Frontend Integration (React)

### app/javascript/components/WishlistButton.jsx
```jsx
import React, { useState, useEffect } from 'react'

const WishlistButton = ({ propertyId, initialFavorite = false }) => {
  const [favorited, setFavorited] = useState(initialFavorite)
  const [loading, setLoading] = useState(false)

  const handleToggle = async () => {
    setLoading(true)

    try {
      const response = await fetch('/api/favorites/toggle', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ property_id: propertyId })
      })

      const data = await response.json()
      setFavorited(data.favorited)
    } catch (error) {
      console.error('Failed to toggle favorite:', error)
    } finally {
      setLoading(false)
    }
  }

  return (
    <button
      onClick={handleToggle}
      disabled={loading}
      className={`favorite-button ${favorited ? 'active' : ''}`}
    >
      {favorited ? '❤️' : '🤍'}
      {favorited ? 'Saved' : 'Save'}
    </button>
  )
}

export default WishlistButton
```

### app/javascript/components/WishlistPage.jsx
```jsx
import React, { useState, useEffect } from 'react'

const WishlistPage = () => {
  const [wishlists, setWishlists] = useState([])
  const [selectedWishlist, setSelectedWishlist] = useState(null)
  const [showCreateModal, setShowCreateModal] = useState(false)

  useEffect(() => {
    fetchWishlists()
  }, [])

  const fetchWishlists = async () => {
    const response = await fetch('/api/wishlists')
    const data = await response.json()
    setWishlists(data)
  }

  const createWishlist = async (name, description, isPublic) => {
    const response = await fetch('/api/wishlists', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        wishlist: { name, description, public: isPublic }
      })
    })

    const newWishlist = await response.json()
    setWishlists([...wishlists, newWishlist])
    setShowCreateModal(false)
  }

  const deleteWishlist = async (id) => {
    await fetch(`/api/wishlists/${id}`, { method: 'DELETE' })
    setWishlists(wishlists.filter(w => w.id !== id))
  }

  return (
    <div className="wishlist-page">
      <h1>Your Wishlists</h1>

      <button onClick={() => setShowCreateModal(true)}>
        Create New Wishlist
      </button>

      <div className="wishlists-grid">
        {wishlists.map(wishlist => (
          <div key={wishlist.id} className="wishlist-card">
            <h3>{wishlist.name}</h3>
            <p>{wishlist.description}</p>
            <span>{wishlist.property_count} properties</span>
            
            <div className="wishlist-actions">
              <button onClick={() => setSelectedWishlist(wishlist)}>
                View
              </button>
              
              {wishlist.share_url && (
                <button onClick={() => navigator.clipboard.writeText(wishlist.share_url)}>
                  Share
                </button>
              )}
              
              <button onClick={() => deleteWishlist(wishlist.id)}>
                Delete
              </button>
            </div>
          </div>
        ))}
      </div>

      {selectedWishlist && (
        <WishlistDetail
          wishlist={selectedWishlist}
          onClose={() => setSelectedWishlist(null)}
        />
      )}

      {showCreateModal && (
        <CreateWishlistModal
          onSubmit={createWishlist}
          onCancel={() => setShowCreateModal(false)}
        />
      )}
    </div>
  )
}

export default WishlistPage
```

## Scheduled Jobs

### app/jobs/price_alert_job.rb
```ruby
class PriceAlertJob < ApplicationJob
  queue_as :default

  def perform(*args)
    PriceAlertService.check_all_price_drops
  end
end
```

### app/jobs/availability_alert_job.rb
```ruby
class AvailabilityAlertJob < ApplicationJob
  queue_as :default

  def perform(*args)
    PriceAlertService.check_availability_alerts
  end
end
```

### config/schedule.rb (using Whenever gem)
```ruby
every 1.day, at: '9:00 am' do
  runner 'PriceAlertJob.perform_later'
end

every 6.hours do
  runner 'AvailabilityAlertJob.perform_later'
end
```

## Testing

### test/services/wishlist_service_test.rb
```ruby
require 'test_helper'

class WishlistServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @service = WishlistService.new(@user)
    @property = properties(:one)
  end

  test 'creates wishlist' do
    wishlist = @service.create_wishlist(
      name: 'Summer Trip',
      description: 'Beach properties',
      public: false
    )

    assert_equal 'Summer Trip', wishlist.name
    assert_equal @user, wishlist.user
  end

  test 'adds property to wishlist' do
    wishlist = @service.create_wishlist(name: 'Favorites')
    item = @service.add_to_wishlist(wishlist.id, @property.id)

    assert_equal @property, item.property
    assert wishlist.has_property?(@property)
  end

  test 'toggles favorite' do
    result = @service.toggle_favorite(@property.id)

    assert result[:favorited]
    assert result[:wishlist]

    result = @service.toggle_favorite(@property.id)

    refute result[:favorited]
  end
end
```

## Deployment Checklist

- [ ] Create database migrations
- [ ] Set up background jobs for alerts
- [ ] Configure email templates for notifications
- [ ] Test sharing functionality
- [ ] Implement rate limiting for shared URLs
- [ ] Add analytics for wishlist engagement
- [ ] Monitor price alert job performance

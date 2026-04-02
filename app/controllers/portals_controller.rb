class PortalsController < ApplicationController
  before_action :authenticate_user!

  def host_dashboard
    @host = current_user
    
    # Get all properties owned by the host
    @properties = Property.where(host_id: @host.id)
    
    # Get bookings for host's properties
    @bookings = Booking.joins(:property)
      .where(properties: { host_id: @host.id })
      .includes(:property, :guest_review)
      .order(created_at: :desc)
      .limit(10)
    
    # Statistics
    @total_properties = @properties.count
    @active_bookings = Booking.joins(:property)
      .where(properties: { host_id: @host.id })
      .where('end_date >= ?', Date.today)
      .count
    
    @completed_bookings = Booking.joins(:property)
      .where(properties: { host_id: @host.id })
      .where('end_date < ?', Date.today)
      .count
    
    @pending_reviews = Booking.joins(:property)
      .where(properties: { host_id: @host.id })
      .where('end_date < ? AND host_reviewed = ?', Date.today, false)
      .count
    
    # Recent messages/conversations
    @conversations = Conversation.joins(:property)
      .where(properties: { host_id: @host.id })
      .includes(:last_message, :booking, :property)
      .order(last_message_at: :desc)
      .limit(5)
    
    # Earnings (if payments exist)
    @total_earnings = Payment.joins(bookings: :property)
      .where(properties: { host_id: @host.id })
      .where(status: 'succeeded')
      .sum(:amount) || 0
    
    render json: {
      host: @host,
      properties: @properties,
      recent_bookings: @bookings,
      statistics: {
        total_properties: @total_properties,
        active_bookings: @active_bookings,
        completed_bookings: @completed_bookings,
        pending_reviews: @pending_reviews,
        total_earnings: @total_earnings
      },
      recent_conversations: @conversations
    }, status: :ok
  end

  def guest_dashboard
    @guest = current_user
    
    # Get guest's bookings
    @bookings = Booking.where(user_id: @guest.id)
      .includes(:property, :guest_review)
      .order(start_date: :desc)
    
    # Upcoming bookings
    @upcoming_bookings = @bookings.where('start_date >= ?', Date.today)
      .order(start_date: :asc)
      .limit(5)
    
    # Past bookings
    @past_bookings = @bookings.where('end_date < ?', Date.today)
      .order(end_date: :desc)
      .limit(5)
    
    # Pending reviews (bookings that need guest review)
    @pending_reviews = @bookings.where('end_date < ? AND guest_reviewed = ?', Date.today, false)
    
    # Guest's wishlists
    @wishlists = Wishlist.where(user_id: @guest.id)
      .includes(:property)
    
    # Total spent
    @total_spent = Payment.joins(:booking)
      .where(bookings: { user_id: @guest.id })
      .where(status: 'succeeded')
      .sum(:amount) || 0
    
    # Active conversations
    @conversations = Conversation.joins(:booking)
      .where(bookings: { user_id: @guest.id })
      .includes(:last_message, :booking, :property)
      .order(last_message_at: :desc)
      .limit(5)
    
    render json: {
      guest: @guest,
      upcoming_bookings: @upcoming_bookings,
      past_bookings: @past_bookings,
      pending_reviews: @pending_reviews,
      wishlists: @wishlists,
      statistics: {
        total_bookings: @bookings.count,
        total_spent: @total_spent,
        upcoming_trips: @upcoming_bookings.count,
        pending_reviews: @pending_reviews.count
      },
      recent_conversations: @conversations
    }, status: :ok
  end
end

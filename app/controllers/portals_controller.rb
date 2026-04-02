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

    # NEW: Facility bookings for host's properties
    @facility_bookings = FacilityBooking.joins(:property)
      .where(properties: { host_id: @host.id })
      .includes(:facility, :guest)
      .order(created_at: :desc)
      .limit(10)

    # Statistics
    @total_properties = @properties.count
    
    # Property bookings stats
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

    # NEW: Facility booking stats
    @total_facilities = Facility.where(property: @properties).count
    @upcoming_facility_bookings = FacilityBooking.joins(:property)
      .where(properties: { host_id: @host.id })
      .where('booking_date >= ?', Date.today)
      .where(status: 'confirmed')
      .count
    
    @pending_facility_bookings = FacilityBooking.joins(:property)
      .where(properties: { host_id: @host.id })
      .where(status: 'pending')
      .count

    @facility_revenue = FacilityBooking.joins(:property)
      .where(properties: { host_id: @host.id })
      .where(status: 'completed')
      .sum(:total_price) || 0

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

    # Total earnings including facilities
    @total_revenue = @total_earnings + @facility_revenue

    render json: {
      host: @host,
      properties: @properties,
      recent_bookings: @bookings,
      recent_facility_bookings: @facility_bookings,
      statistics: {
        total_properties: @total_properties,
        active_bookings: @active_bookings,
        completed_bookings: @completed_bookings,
        pending_reviews: @pending_reviews,
        total_facilities: @total_facilities,
        upcoming_facility_bookings: @upcoming_facility_bookings,
        pending_facility_bookings: @pending_facility_bookings,
        facility_revenue: @facility_revenue,
        total_earnings: @total_earnings,
        total_revenue: @total_revenue
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

    # NEW: Facility bookings
    @facility_bookings = FacilityBooking.where(user_id: @guest.id)
      .includes(:facility, :property)
      .order(booking_date: :desc)
    
    @upcoming_facility_bookings = @facility_bookings
      .where('booking_date >= ?', Date.today)
      .where.not(status: 'cancelled')
      .order(booking_date: :asc)
      .limit(5)

    @past_facility_bookings = @facility_bookings
      .where('booking_date < ?', Date.today)
      .order(booking_date: :desc)
      .limit(5)

    @pending_facility_reviews = @facility_bookings
      .joins(:facility_review)
      .where('facility_bookings.status = ? AND facility_bookings.booking_date < ?', 'completed', Date.today)
      .where(facility_reviews: { id: nil })

    # Guest's wishlists
    @wishlists = Wishlist.where(user_id: @guest.id)
      .includes(:property)

    # Total spent on property bookings
    @total_spent = Payment.joins(:booking)
      .where(bookings: { user_id: @guest.id })
      .where(status: 'succeeded')
      .sum(:amount) || 0

    # Total spent on facility bookings
    @facility_spent = FacilityBooking.where(user_id: @guest.id)
      .where(status: 'completed')
      .sum(:total_price) || 0

    @total_guest_spent = @total_spent + @facility_spent

    # NEW: Member points
    @available_points = MemberPoint.total_active_points(@guest.id)

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
      upcoming_facility_bookings: @upcoming_facility_bookings,
      past_facility_bookings: @past_facility_bookings,
      pending_reviews: @pending_reviews,
      pending_facility_reviews: @pending_facility_reviews,
      wishlists: @wishlists,
      available_points: @available_points,
      statistics: {
        total_bookings: @bookings.count,
        total_facility_bookings: @facility_bookings.count,
        total_spent: @total_spent,
        facility_spent: @facility_spent,
        total_guest_spent: @total_guest_spent,
        upcoming_trips: @upcoming_bookings.count,
        upcoming_facility_sessions: @upcoming_facility_bookings.count,
        pending_reviews: @pending_reviews.count,
        pending_facility_reviews: @pending_facility_reviews.count,
        available_points: @available_points
      },
      recent_conversations: @conversations
    }, status: :ok
  end
end

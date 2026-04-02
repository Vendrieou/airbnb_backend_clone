module Admin
  class FacilityBookingsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin_or_host

    def index
      @bookings = FacilityBooking
        .joins(:facility)
        .where(facilities: { host_id: current_host.id })
        .includes(:guest, :facility, :property)
        .order(created_at: :desc)
        .page(params[:page])
      
      @status_filter = params[:status] || 'all'
      @bookings = @bookings.where(status: @status_filter) if @status_filter != 'all'
    end

    def show
      @booking = FacilityBooking
        .joins(:facility)
        .where(facilities: { host_id: current_host.id })
        .find(params[:id])
    end

    def approve
      @booking = FacilityBooking
        .joins(:facility)
        .where(facilities: { host_id: current_host.id })
        .find(params[:id])
      
      if @booking.pending?
        @booking.update!(status: 'confirmed')
        FacilityBookingNotificationJob.perform_later(@booking.id, :guest_confirmation)
        redirect_to admin_facility_booking_path(@booking), notice: "Booking approved successfully."
      else
        redirect_to admin_facility_booking_path(@booking), alert: "Booking cannot be approved."
      end
    end

    def reject
      @booking = FacilityBooking
        .joins(:facility)
        .where(facilities: { host_id: current_host.id })
        .find(params[:id])
      
      if @booking.pending?
        @booking.update!(status: 'rejected')
        FacilityBookingNotificationJob.perform_later(@booking.id, :cancellation)
        redirect_to admin_facility_booking_path(@booking), notice: "Booking rejected."
      else
        redirect_to admin_facility_booking_path(@booking), alert: "Booking cannot be rejected."
      end
    end

    def cancel
      @booking = FacilityBooking
        .joins(:facility)
        .where(facilities: { host_id: current_host.id })
        .find(params[:id])
      
      if @booking.confirmed?
        @booking.update!(status: 'cancelled_by_host')
        process_refund(@booking)
        FacilityBookingNotificationJob.perform_later(@booking.id, :cancellation)
        redirect_to admin_facility_booking_path(@booking), notice: "Booking cancelled and refund processed."
      else
        redirect_to admin_facility_booking_path(@booking), alert: "Booking cannot be cancelled."
      end
    end

    private

    def require_admin_or_host
      unless current_user.admin? || current_user.host?
        redirect_to root_path, alert: "Access denied."
      end
    end

    def process_refund(booking)
      # Integrate with payment processor for refunds
      # PaymentProcessor.refund(booking.payment) if booking.payment
    end
  end
end

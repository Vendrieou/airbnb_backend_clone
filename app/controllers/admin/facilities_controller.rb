module Admin
  class FacilitiesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin_or_host

    def index
      @facilities = current_host.facilities
        .includes(:property)
        .order(created_at: :desc)
        .page(params[:page])
    end

    def new
      @facility = current_host.facilities.build
      @properties = current_host.properties
    end

    def create
      @facility = current_host.facilities.build(facility_params)
      
      if @facility.save
        redirect_to admin_facilities_path, notice: "Facility created successfully."
      else
        @properties = current_host.properties
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @facility = current_host.facilities.find(params[:id])
      @properties = current_host.properties
    end

    def update
      @facility = current_host.facilities.find(params[:id])
      
      if @facility.update(facility_params)
        redirect_to admin_facilities_path, notice: "Facility updated successfully."
      else
        @properties = current_host.properties
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @facility = current_host.facilities.find(params[:id])
      
      if @facility.bookings.future.empty?
        @facility.destroy
        redirect_to admin_facilities_path, notice: "Facility deleted successfully."
      else
        redirect_to admin_facilities_path, alert: "Cannot delete facility with upcoming bookings."
      end
    end

    def availability
      @facility = current_host.facilities.find(params[:id])
      @bookings = @facility.bookings.where('booking_date >= ?', Date.today)
        .order(booking_date: :asc, start_time: :asc)
    end

    private

    def require_admin_or_host
      unless current_user.admin? || current_user.host?
        redirect_to root_path, alert: "Access denied."
      end
    end

    def facility_params
      params.require(:facility).permit(
        :name,
        :description,
        :facility_type,
        :price,
        :slot_interval_minutes,
        :max_advance_booking_days,
        :min_advance_booking_hours,
        :active,
        :property_id,
        :amenities,
        :images,
        :rules
      )
    end
  end
end

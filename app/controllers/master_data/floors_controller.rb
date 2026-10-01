# frozen_string_literal: true
#
# Master data lantai (floor). UI bisa tambah/edit/hapus floor per hotel.
module MasterData
  class FloorsController < ApplicationController
    before_action :set_hotel, only: [:index, :create]
    before_action :set_floor, only: [:update, :destroy]

    # GET /master_data/hotels/:hotel_id/floors
    def index
      floors = @hotel.hotel_floors.includes(:rooms)
      render json: {
        floors: floors.map do |f|
          {
            id: f.id, floor_number: f.floor_number, floor_name: f.floor_name,
            rooms_count: f.rooms.size,
            available_count: f.rooms.count { |r| r.status == "available" },
          }
        end,
      }
    end

    # POST /master_data/hotels/:hotel_id/floors
    def create
      floor = @hotel.hotel_floors.new(floor_params)
      if floor.save
        render json: { floor: floor_json(floor) }, status: :created
      else
        render json: { errors: floor.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /master_data/floors/:id
    def update
      if @floor.update(floor_params)
        render json: { floor: floor_json(@floor) }
      else
        render json: { errors: @floor.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /master_data/floors/:id  (hanya bila tidak ada unit di atasnya)
    def destroy
      if @floor.rooms.exists?
        render json: { error: "Lantai masih punya #{@floor.rooms.count} unit. Pindahkan/hapus unit dulu." },
               status: :unprocessable_entity
      else
        @floor.destroy!
        render json: { ok: true }
      end
    end

    private

    def set_hotel
      @hotel = Hotel.find(params[:hotel_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Hotel tidak ditemukan" }, status: :not_found
    end

    def set_floor
      @floor = HotelFloor.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Lantai tidak ditemukan" }, status: :not_found
    end

    def floor_params
      params.permit(:floor_number, :floor_name)
    end

    def floor_json(f)
      { id: f.id, hotel_id: f.hotel_id, floor_number: f.floor_number, floor_name: f.floor_name }
    end
  end
end

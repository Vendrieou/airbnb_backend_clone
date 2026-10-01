# frozen_string_literal: true
#
# Master data unit kamar dalam bentuk GRID per lantai (floor plan).
# - GET  /master_data/hotels/:hotel_id/grid   -> semua lantai + unit tersusun grid
# - POST /master_data/hotels/:hotel_id/rooms  -> tambah unit (auto-place di grid)
# - GET/PATCH /master_data/rooms/:id          -> detail/edit unit (+ posisi grid)
module MasterData
  class RoomsController < ApplicationController
    before_action :set_hotel, only: [:grid, :create]
    before_action :set_room, only: [:show, :update, :destroy]

    # GET /master_data/hotels/:hotel_id/grid
    def grid
      floors = @hotel.hotel_floors.includes(rooms: [{ room_type: [], smart_lock_device: [] }])
      render json: {
        hotel: { id: @hotel.id, name: @hotel.name, code: @hotel.code },
        floors: floors.map do |f|
          {
            id: f.id, floor_number: f.floor_number, floor_name: f.floor_name,
            rooms: f.rooms.map { |r| room_json(r) },
          }
        end,
      }
    end

    # GET /master_data/rooms/:id  (detail unit utk modal edit)
    def show
      render json: { room: room_json(@room, detailed: true) }
    end

    # POST /master_data/hotels/:hotel_id/rooms
    # body: room_number, floor_id, room_type_id, status?, grid_row?, grid_col?
    def create
      room = Room.new(
        room_number: params.require(:room_number),
        room_type_id: params.require(:room_type_id),
        floor_id: params[:floor_id],
        status: params.fetch(:status, "available"),
        grid_row: params[:grid_row],
        grid_col: params[:grid_col],
      )
      # auto-place di grid bila posisi kosong: kolom berikutnya pada baris terakhir
      if room.grid_col.nil?
        col = (Room.where(floor_id: room.floor_id).maximum(:grid_col) || 0) + 1
        row = room.grid_row || ((col - 1) / 8) + 1
        room.grid_col = ((col - 1) % 8) + 1
        room.grid_row = row
      end
      if room.save
        render json: { room: room_json(room) }, status: :created
      else
        render json: { errors: room.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /master_data/rooms/:id  (drag & drop grid, ganti tipe/status, notes)
    def update
      if @room.update(params.permit(:room_number, :room_type_id, :floor_id, :status, :notes, :grid_row, :grid_col))
        render json: { room: room_json(@room) }
      else
        render json: { errors: @room.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /master_data/rooms/:id (blokir bila masih lock/booking aktif)
    def destroy
      if @room.smart_lock_device&.door_temporary_keys&.valid_now&.exists?
        render json: { error: "Masih ada passcode aktif pada lock unit ini." }, status: :unprocessable_entity
        return
      end
      @room.destroy!
      render json: { ok: true }
    end

    private

    def set_hotel
      @hotel = Hotel.find(params[:hotel_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Hotel tidak ditemukan" }, status: :not_found
    end

    def set_room
      @room = Room.includes(:room_type, :floor, smart_lock_device: [:door_master_keys, :door_temporary_keys]).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Unit tidak ditemukan" }, status: :not_found
    end

    def room_json(r, detailed: false)
      j = {
        id: r.id, room_number: r.room_number, status: r.status,
        floor_id: r.floor_id, floor_number: r.floor&.floor_number,
        room_type: r.room_type&.name, room_type_id: r.room_type_id,
        grid_row: r.grid_row || 1, grid_col: r.grid_col || 1,
        has_lock: r.smart_lock_device.present?,
        needs_housekeeping: r.needs_housekeeping?,
      }
      if detailed
        j[:notes] = r.notes
        j[:smart_lock] = r.smart_lock_device&.public_json
        j[:master_keys] = r.smart_lock_device&.door_master_keys&.map(&:public_json) || []
        j[:temporary_keys] = r.smart_lock_device&.door_temporary_keys&.order(created_at: :desc)&.limit(10)&.map { |k| k.public_json(show_secret: true) } || []
      end
      j
    end
  end
end

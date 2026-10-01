# frozen_string_literal: true
#
# Setup smart lock pada unit kamar (dibuka dari modal "Edit Detail Unit"):
#  - master config : pairing device (7EVEN KEY / TTLOCK) + master passcode
#  - master key    : RFID card / PIN induk / fingerprint
#  - temporary key : passcode generated utk guest/staf (window waktu + limit)
module MasterData
  class SmartLocksController < ApplicationController
    before_action :set_room, only: [:show, :create_or_update]
    before_action :set_device, only: [:update_master_config, :pair, :refresh,
                                      :create_master_key, :revoke_master_key,
                                      :generate_temp_key, :revoke_temp_key]

    # GET /master_data/rooms/:room_id/smart_lock
    def show
      unless @room.smart_lock_device
        render json: { smart_lock: nil, message: "Unit ini belum punya smart lock." } and return
      end
      @device = @room.smart_lock_device
      render json: {
        smart_lock: @device.public_json.merge(
          master_keys: @device.door_master_keys.map(&:public_json),
          temporary_keys: @device.door_temporary_keys.order(created_at: :desc).limit(20)
                              .map { |k| k.public_json(show_secret: true) },
        ),
      }
    end

    # POST /master_data/rooms/:room_id/smart_lock
    # body: brand(seven_key|ttlock), device_name, mac_address | device_trid+device_pass_code(+device_api_key)
    def create_or_update
      device = @room.smart_lock_device || @room.build_smart_lock_device
      device.assign_attributes(params.permit(:brand, :device_type, :device_name, :mac_address,
                                             :device_trid, :device_pass_code, :device_api_key,
                                             :firmware_version))
      if device.save
        render json: { smart_lock: device.public_json }, status: :created
      else
        render json: { errors: device.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /master_data/smart_locks/:id/master_config
    # body: master_passcode (4-10 digit) -> push ke lock via gateway
    def update_master_config
      code = params.require(:master_passcode)
      SmartLockGateway.new(@device).set_master_passcode!(code)
      render json: { smart_lock: @device.reload.public_json, message: "Master passcode tersimpan & dikirim ke lock." }
    rescue SmartLockGateway::Error => e
      render json: { error: e.message }, status: :bad_request
    end

    # POST /master_data/smart_locks/:id/pair  (pairing ke cloud provider)
    def pair
      SmartLockGateway.new(@device).pair!
      render json: { smart_lock: @device.reload.public_json, message: "Device berhasil dipairing." }
    rescue SmartLockGateway::Error => e
      @device.update(status: "error")
      render json: { error: "Pairing gagal: #{e.message}" }, status: :unprocessable_entity
    end

    # POST /master_data/smart_locks/:id/refresh  (baterai/online status)
    def refresh
      SmartLockGateway.new(@device).refresh_status!
      render json: { smart_lock: @device.reload.public_json }
    rescue SmartLockGateway::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # ---- MASTER KEYS ----
    # POST /master_data/smart_locks/:id/master_keys
    # body: key_type(rfid_card|pin|fingerprint|app_ble), name, identifier?, pin_code?, valid_from?, expires_on?
    def create_master_key
      key = @device.door_master_keys.new(params.permit(:key_type, :name, :identifier, :pin_code, :valid_from, :expires_on))
      if key.save
        render json: { master_key: key.public_json }, status: :created
      else
        render json: { errors: key.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /master_data/smart_locks/:id/master_keys/:master_key_id
    def revoke_master_key
      key = @device.door_master_keys.find(params[:master_key_id])
      key.revoke!
      render json: { ok: true }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Master key tidak ditemukan" }, status: :not_found
    end

    # ---- TEMPORARY KEYS (passcode generated) ----
    # POST /master_data/smart_locks/:id/temporary_keys
    # body: kind(passcode|ic_card), label?, start_at, end_at, times_limit?, user_id?, booking_id?
    def generate_temp_key
      key = @device.door_temporary_keys.new(
        params.permit(:kind, :label, :start_at, :end_at, :times_limit, :user_id, :booking_id, :rental_booking_id)
              .with_defaults(kind: "passcode"),
      )
      unless key.save
        render json: { errors: key.errors.full_messages }, status: :unprocessable_entity and return
      end
      key.generate_passcode! if key.kind == "passcode"
      synced = false
      begin
        key.sync_to_device! if @device.paired?
        synced = key.status == "synced"
      rescue SmartLockGateway::Error => e
        render json: { error: "Passcode dibuat tapi gagal sync: #{e.message}",
                       temporary_key: key.reload.public_json(show_secret: true) }, status: :ok and return
      end
      render json: { temporary_key: key.public_json(show_secret: true), synced: synced }, status: :created
    end

    # DELETE /master_data/smart_locks/:id/temporary_keys/:temp_key_id
    def revoke_temp_key
      key = @device.door_temporary_keys.find(params[:temp_key_id])
      key.revoke!
      render json: { ok: true }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Temporary key tidak ditemukan" }, status: :not_found
    end

    private

    def set_room
      @room = Room.find(params[:room_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Unit tidak ditemukan" }, status: :not_found
    end

    def set_device
      @device = SmartLockDevice.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Smart lock tidak ditemukan" }, status: :not_found
    end
  end
end

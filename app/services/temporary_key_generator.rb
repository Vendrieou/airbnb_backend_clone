# frozen_string_literal: true
#
# Generate temporary key / passcode utk satu booking (hotel Booking atau
# RentalBooking). Window aktif = check-in 15:00 s/d checkout 12:00.
# Kalau lock belum terpasang -> dibuat pending, passcode tetap digenerate
# supaya guest bisa lihat di detail booking.
class TemporaryKeyGenerator
  DEFAULT_TIMES_LIMIT = 20

  Result = Struct.new(:key, :synced, :error, keyword_init: true)

  def initialize(booking:, kind: "passcode", label: nil, times_limit: nil)
    @booking = booking
    @kind = kind
    @label = label
    @times_limit = times_limit || DEFAULT_TIMES_LIMIT
  end

  def call
    room = resolve_room
    return Result.new(key: nil, synced: false, error: "Booking tidak terhubung ke kamar/unit") unless room

    device = room.smart_lock_device || SmartLockDevice.create!(room: room, brand: default_brand)

    key = DoorTemporaryKey.create!(
      smart_lock_device: device,
      **booking_refs,
      kind: @kind,
      label: @label || "Guest #{@booking.try(:guest)&.name || 'user'} · #{@booking.class.name.demodulize} ##{@booking.id}",
      start_at: check_in_time,
      end_at: check_out_time,
      times_limit: @times_limit,
    )
    key.generate_passcode! if @kind == "passcode"

    synced = false
    error = nil
    if device.paired?
      begin
        key.sync_to_device!
        synced = true
      rescue SmartLockGateway::Error => e
        error = e.message
      end
    else
      error = "Lock belum dipairing — passcode aktif lokal, sync saat device online."
    end

    notify_guest(key) if synced || @kind == "passcode"
    Result.new(key: key, synced: synced, error: error)
  end

  private

  def booking_refs
    if @booking.is_a?(RentalBooking)
      { rental_booking_id: @booking.id, user_id: @booking.guest_id }
    else
      { booking_id: @booking.id, user_id: @booking.user_id }
    end
  end

  def resolve_room
    if @booking.respond_to?(:room) && @booking.room
      @booking.room
    elsif @booking.respond_to?(:facility) && @booking.facility
      FacilityRoomResolver.call(@booking.facility) # helper existing jika ada
    end
  rescue StandardError
    nil
  end

  def default_brand
    ENV.fetch("SMART_LOCK_DEFAULT_BRAND", "seven_key")
  end

  def check_in_time
    d = (@booking.check_in || @booking.try(:start_date)) || Date.current
    to_date(d).change(hour: 15)
  rescue StandardError
    Time.current
  end

  def check_out_time
    d = (@booking.check_out || @booking.try(:end_date)) || (Date.current + 1)
    to_date(d).change(hour: 12)
  rescue StandardError
    Time.current + 1.day
  end

  def to_date(d)
    d.is_a?(Date) ? d : Date.parse(d.to_s)
  end

  def notify_guest(key)
    return unless key.passcode.present?
    guest = @booking.try(:guest) || @booking.try(:user)
    return unless guest&.respond_to?(:phone) && guest.phone.present?
    WhatsappNotifier.temporary_key(guest, key) if WhatsappNotifier.respond_to?(:temporary_key)
  rescue StandardError => e
    Rails.logger.warn("[TemporaryKeyGenerator] notify failed: #{e.message}")
  end
end

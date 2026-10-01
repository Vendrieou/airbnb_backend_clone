# frozen_string_literal: true
#
# Perangkat smart lock per kamar. Mendukung 2 brand:
# - "seven_key" (7EVEN KEY): pairing via MAC address
# - "ttlock"   (TTLOCK)    : pairing via deviceTrid + passCode + serverKey
#
# "Master config" = identitas perangkat + master passcode (PIN induk lock).
class SmartLockDevice < ApplicationRecord
  belongs_to :room
  has_many :door_master_keys, dependent: :destroy
  has_many :door_temporary_keys, dependent: :destroy

  BRANDS = %w[seven_key ttlock].freeze
  STATUSES = %w[unpaired paired offline error].freeze

  validates :brand, inclusion: { in: BRANDS }
  validates :status, inclusion: { in: STATUSES }
  validates :device_trid, uniqueness: true, allow_nil: true
  validates :device_trid, presence: true, if: -> { brand == "ttlock" }
  validates :mac_address, presence: true, if: -> { brand == "seven_key" }
  validates :battery_level, numericality: { in: 0..100 }, allow_nil: true

  scope :paired, -> { where(status: "paired") }
  scope :for_brand, ->(b) { where(brand: b) }

  def seven_key?
    brand == "seven_key"
  end

  def ttlock?
    brand == "ttlock"
  end

  def paired?
    status == "paired"
  end

  # Pairing ke cloud provider (dev: fake gateway, log-only).
  def pair!
    SmartLockGateway.new(self).pair!
  end

  def mark_synced!
    update!(last_synced_at: Time.current, online: true, status: "paired")
  end

  # Ringkasan utk UI — JANGAN pernah kirim master_passcode / device_api_key mentah.
  def public_json
    {
      id: id, room_id: room_id, brand: brand, device_type: device_type,
      device_name: device_name || room&.room_number,
      mac_address: mac_address, device_trid: device_trid,
      firmware_version: firmware_version, battery_level: battery_level,
      online: online, status: status, last_synced_at: last_synced_at,
      master_passcode_set: master_passcode.present?,
    }
  end
end

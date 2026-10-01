# frozen_string_literal: true
#
# Master key pada satu smart lock: kartu RFID induk, PIN induk, fingerprint admin,
# atau akses app BLE. Berbeda dgn temporary key (passcode guest yg expire otomatis).
class DoorMasterKey < ApplicationRecord
  belongs_to :smart_lock_device

  KEY_TYPES = %w[rfid_card pin fingerprint app_ble].freeze

  validates :key_type, inclusion: { in: KEY_TYPES }
  validates :name, presence: true
  validates :identifier, presence: true, unless: -> { key_type == "pin" }
  validate :pin_required_for_pin_type

  scope :active, -> { where(active: true) }

  def revoke!
    update!(active: false, revoked_at: Time.current)
    SmartLockGateway.new(smart_lock_device).delete_key!(self) rescue nil
  end

  def expired?
    expires_on.present? && expires_on < Date.current
  end

  def public_json
    {
      id: id, key_type: key_type, name: name, identifier: identifier,
      valid_from: valid_from, expires_on: expires_on,
      active: active, revoked_at: revoked_at,
      pin_code_masked: pin_code.present? ? "•" * pin_code.length : nil,
    }
  end

  private

  def pin_required_for_pin_type
    errors.add(:pin_code, "wajib diisi untuk key type PIN") if key_type == "pin" && pin_code.blank?
  end
end

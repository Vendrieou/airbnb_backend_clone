# frozen_string_literal: true
#
# Temporary key / passcode yang di-generate utk guest (check-in s/d checkout),
# housekeeper, atau maintenance. Mirip fitur "Temporary Passcode" di TTLOCK &
# "Temp Key" di 7EVEN KEY: punya window waktu, bisa dibatasi jumlah buka pintu,
# dan bisa dicabut (revoke) kapan saja.
class DoorTemporaryKey < ApplicationRecord
  belongs_to :smart_lock_device
  belongs_to :booking, optional: true
  belongs_to :rental_booking, optional: true
  belongs_to :user, optional: true

  KINDS = %w[passcode ic_card fingerprint].freeze
  STATUSES = %w[pending active synced expired revoked failed].freeze

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :start_at, :end_at, presence: true
  validate :end_after_start

  scope :valid_now, -> { where(status: %w[active synced]).where("start_at <= ? AND end_at >= ?", Time.current, Time.current) }

  def generate_passcode!
    # 6 digit acak, unik utk device aktif ini
    loop do
      code = SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
      next if code.all? { |c| c == code[0] } # hindari 000000/111111
      unless self.class.where(smart_lock_device_id: smart_lock_device_id,
                              passcode: code, status: %w[pending active synced]).exists?
        update!(passcode: code, status: "active")
        break
      end
    end
    self
  end

  def sync_to_device!
    SmartLockGateway.new(smart_lock_device).add_key!(self)
    update!(status: "synced", synced_at: Time.current)
  end

  def revoke!
    update!(status: "revoked", revoked_at: Time.current)
    SmartLockGateway.new(smart_lock_device).delete_key!(self) rescue nil
  end

  def active_window?
    status.in?(%w[active synced]) && start_at <= Time.current && end_at >= Time.current
  end

  # Tampilkan passcode HANYA saat masih dalam window aktif (keamanan).
  def public_json(show_secret: false)
    {
      id: id, kind: kind, label: label,
      start_at: start_at, end_at: end_at,
      times_limit: times_limit, times_used: times_used,
      status: status, remote_key_id: remote_key_id, synced_at: synced_at,
      passcode: show_secret && active_window? ? passcode : nil,
      ic_card_number: ic_card_number,
    }
  end

  private

  def end_after_start
    return unless start_at && end_at
    errors.add(:end_at, "harus setelah start_at") if end_at <= start_at
  end
end

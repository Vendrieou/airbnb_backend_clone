# frozen_string_literal: true
#
# HousekeepingTask = task kerja untuk housekeeper yang dibuat otomatis
# oleh algoritma HousekeepingTriggerService ketika sebuah kamar terdeteksi
# KOSONG / CHECKOUT DAN TIDAK DIPERPANJANG setelah H-3 (end_date + 3 hari
# lewat tanpa booking lanjutan).
#
# Task ini juga menjadi kartu pada Kanban board (HousekeepingBoard)
# dengan lifecycle kolom: draft -> todo -> in_progress -> review -> done.
class HousekeepingTask < ApplicationRecord
  include ErrorHandling

  TASK_TYPES = %w[cleaning deep_cleaning linen_change inspection maintenance_follow_up].freeze
  PRIORITIES = %w[low medium high urgent].freeze
  # Kolom Kanban. `review` dipakai sebagai tahap "menunggu validasi"
  # sebelum kartu boleh dipindah ke `done` (butuh minimal 1 foto bukti).
  BOARD_STATUSES = %w[draft todo in_progress review done].freeze
  CLOSED_STATUSES = %w[done cancelled].freeze

  belongs_to :room
  belongs_to :property
  belongs_to :hotel, optional: true
  belongs_to :board, class_name: 'HousekeepingBoard', foreign_key: :housekeeping_board_id, optional: true
  belongs_to :last_booking, class_name: 'Booking', foreign_key: :last_booking_id, optional: true
  belongs_to :assigned_to, class_name: 'User', foreign_key: :assigned_to_id, optional: true
  belongs_to :created_by, class_name: 'User', foreign_key: :created_by_id, optional: true

  has_many :attachments, class_name: 'HousekeepingTaskAttachment',
           foreign_key: :housekeeping_task_id,
           dependent: :destroy

  validates :title, presence: true
  validates :task_type, inclusion: { in: TASK_TYPES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :status, inclusion: { in: BOARD_STATUSES + %w[cancelled] }

  scope :open, -> { where.not(status: CLOSED_STATUSES) }
  scope :open_or_all, ->(all: false) { all ? all : open }
  scope :by_status, ->(status) { where(status: status) }
  scope :for_room, ->(room_id) { where(room_id: room_id) }
  scope :due_before, ->(date) { where(due_at: ..date.end_of_day) }
  scope :overdue, -> { open.where("due_at < ?", Time.current) }

  def open?
    !CLOSED_STATUSES.include?(status)
  end

  def done?
    status == 'done'
  end

  # Pindahkan kartu ke kolom berikutnya di board (draft -> todo -> ... -> done).
  # Memindahan ke 'done' wajib ada minimal satu foto bukti (attachable image).
  def advance!(actor = nil)
    idx = BOARD_STATUSES.index(status)
    raise InvalidDateRangeError, "Task sudah berada di kolom terakhir (#{status})" if idx.nil? || idx == BOARD_STATUSES.size - 1

    next_status = BOARD_STATUSES[idx + 1]
    move_to!(next_status, actor)
  end

  def move_to!(new_status, actor = nil)
    unless BOARD_STATUSES.include?(new_status)
      raise BookingError, "Status tidak valid: #{new_status}"
    end

    if new_status == 'done' && photo_count.zero?
      raise BookingError, "Tidak bisa menyelesaikan task tanpa upload foto bukti (min. 1 image)"
    end

    transaction do
      update!(status: new_status, completed_at: new_status == 'done' ? Time.current : completed_at)
      log_activity(actor, "pindah ke kolom #{new_status}")
      sync_room_status_if_done!
      self
    end
  end

  def photo_count
    attachments.count { |a| a.image? }
  end

  def log_activity(actor, message)
    HousekeepingActivity.create!(
      housekeeping_task_id: id,
      user: actor,
      action: message
    )
  end

  private

  # Setelah kartu sampai kolom 'done', kamar boleh kembali dijual.
  def sync_room_status_if_done!
    return unless status == 'done'
    return if HousekeepingTask.open.for_room(room_id).where.not(id: id).exists?

    room.check_out! if room.maintenance? || room.status == 'occupied'
  end
end

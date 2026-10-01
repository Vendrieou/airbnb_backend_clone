# frozen_string_literal: true
#
# HousekeepingBoard = papan Kanban housekeeping per properti/hotel.
# Kolom tetap: draft -> todo -> in_progress -> review -> done
# (lihat HousekeepingTask::BOARD_STATUSES).
class HousekeepingBoard < ApplicationRecord
  belongs_to :property
  belongs_to :hotel, optional: true

  has_many :tasks, class_name: 'HousekeepingTask',
           foreign_key: :housekeeping_board_id,
           dependent: :nullify

  validates :name, presence: true

  DEFAULT_COLUMNS = HousekeepingTask::BOARD_STATUSES

  # Isi board per kolom, siap dikonsumsi UI Kanban (drag & drop).
  def columns(with_open_tasks_only: false)
    tasks_scope = tasks.includes(:room, :attachments, assigned_to: [], last_booking: [])
    tasks_scope = tasks_scope.open if with_open_tasks_only

    DEFAULT_COLUMNS.index_with do |column|
      tasks_scope.by_status(column).order(Arel.sql("CASE priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END"), due_at: :asc)
    end
  end

  def task_counts
    counts = tasks.group(:status).count
    DEFAULT_COLUMNS.index_with { |c| counts.fetch(c, 0) }
  end
end

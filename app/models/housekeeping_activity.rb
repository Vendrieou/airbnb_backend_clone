# frozen_string_literal: true
#
# Audit trail pergerakan kartu Kanban & notifikasi housekeeping.
class HousekeepingActivity < ApplicationRecord
  belongs_to :housekeeping_task
  belongs_to :user, optional: true

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc).limit(50) }
end

# frozen_string_literal: true
#
# Bukti kerja housekeeper pada kartu Kanban: upload image (foto sebelum/sesudah)
# atau file lain (mis. PDF checklist).
class HousekeepingTaskAttachment < ApplicationRecord
  IMAGE_EXTENSIONS = %w[jpg jpeg png webp gif heic].freeze
  MAX_IMAGE_BYTES = 10.megabytes

  belongs_to :housekeeping_task

  validates :file_url, presence: true
  validate :image_size_within_limit

  scope :images, -> { where(kind: 'image') }

  def image?
    kind == 'image'
  end

  def self.kind_for(filename)
    ext = File.extname(filename.to_s).delete('.').downcase
    IMAGE_EXTENSIONS.include?(ext) ? 'image' : 'file'
  end

  private

  def image_size_within_limit
    return unless image?
    errors.add(:file_size, "maks #{MAX_IMAGE_BYTES / 1.megabyte}MB") if file_size.to_i > MAX_IMAGE_BYTES
  end
end

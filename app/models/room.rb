class Room < ApplicationRecord
  belongs_to :room_type
  belongs_to :floor, class_name: 'HotelFloor', optional: true
  has_many :invoice_lines, dependent: :nullify

  validates :room_number, presence: true, uniqueness: { scope: :room_type_id }
  validates :status, inclusion: { 
    in: %w[available occupied maintenance out_of_order],
    message: "must be one of: available, occupied, maintenance, out_of_order"
  }

  scope :available, -> { where(status: 'available') }
  scope :occupied, -> { where(status: 'occupied') }
  scope :maintenance, -> { where(status: 'maintenance') }
  scope :out_of_order, -> { where(status: 'out_of_order') }

  # Check if room is available for booking
  def available?
    status == 'available'
  end

  # Mark room as occupied
  def occupy!
    update!(status: 'occupied')
  end

  # Mark room as available after checkout
  def check_out!
    update!(status: 'available')
  end

  # Mark room for maintenance
  def mark_for_maintenance!(notes = nil)
    update!(status: 'maintenance', notes: notes)
  end

  # Return room to service
  def return_to_service!
    update!(status: 'available', notes: nil)
  end
end

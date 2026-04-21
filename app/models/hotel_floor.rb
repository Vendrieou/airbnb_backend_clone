class HotelFloor < ApplicationRecord
  belongs_to :hotel
  has_many :room_types, dependent: :nullify
  has_many :rooms, dependent: :nullify

  validates :floor_number, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :floor_number, uniqueness: { scope: :hotel_id }

  default_scope { order(floor_number: :asc) }

  # Get all rooms on this floor
  def all_rooms
    Room.joins(:room_type).where(room_types: { floor_id: id })
  end

  # Get available rooms on this floor
  def available_rooms
    all_rooms.where(status: 'available')
  end
end

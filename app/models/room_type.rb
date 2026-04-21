class RoomType < ApplicationRecord
  belongs_to :hotel
  belongs_to :floor, class_name: 'HotelFloor', optional: true
  has_and_belongs_to_many :amenities
  has_many :rooms, dependent: :destroy
  has_many :invoice_lines, dependent: :nullify

  validates :name, presence: true
  validates :code, presence: true, uniqueness: { scope: :hotel_id }
  validates :max_adult, numericality: { greater_than: 0 }, allow_nil: false
  validates :size_sqm, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :base_price, numericality: { greater_than_or_equal_to: 0 }

  validate :adult_capacity_must_be_positive

  scope :active, -> { where(active: true) }
  scope :by_hotel, ->(hotel_id) { where(hotel_id: hotel_id) }
  scope :with_available_rooms, -> { joins(:rooms).where(rooms: { status: 'available' }).distinct }

  # Get count of available rooms for this room type
  def available_rooms_count
    rooms.where(status: 'available').count
  end

  # Check if this room type has any available rooms
  def has_available_rooms?
    available_rooms_count > 0
  end

  # Calculate average price including taxes from invoice lines
  def average_price
    invoice_lines.average(:price_total)&.to_f&.round(2) || base_price
  end

  private

  def adult_capacity_must_be_positive
    if max_adult.nil? || max_adult <= 0
      errors.add(:max_adult, "must be greater than zero for occupancy rules")
    end
  end
end

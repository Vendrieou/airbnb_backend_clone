class Amenity < ApplicationRecord
  has_and_belongs_to_many :room_types

  validates :name, presence: true
  validates :category, presence: true

  scope :active, -> { where(active: true) }
  scope :by_category, ->(category) { where(category: category) }

  # Get all unique categories
  def self.categories
    distinct.pluck(:category).sort
  end

  # Get amenities for a specific room type
  def self.for_room_type(room_type_id)
    joins(:room_types).where(room_types: { id: room_type_id })
  end
end

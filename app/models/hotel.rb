class Hotel < ApplicationRecord
  has_many :hotel_floors, dependent: :destroy
  has_many :room_types, dependent: :destroy
  has_many :rooms, through: :room_types
  has_many :invoices, dependent: :destroy

  validates :name, presence: true
  validates :code, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :active, -> { where(active: true) }

  # Calculate total revenue from invoices
  def total_revenue
    invoices.where(state: %w[posted paid]).sum(:amount_total)
  end

  # Get available room types
  def available_room_types
    room_types.active.includes(:rooms).where(rooms: { status: 'available' }).distinct
  end
end

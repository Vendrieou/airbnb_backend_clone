class InvoiceLine < ApplicationRecord
  belongs_to :invoice
  belongs_to :room_type, optional: true
  belongs_to :room, optional: true

  validates :description, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :price_unit, numericality: { greater_than_or_equal_to: 0 }
  validates :tax_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  before_save :calculate_subtotal_and_total

  scope :for_invoice, ->(invoice_id) { where(invoice_id: invoice_id) }
  scope :with_room_type, -> { where.not(room_type_id: nil) }
  scope :with_room, -> { where.not(room_id: nil) }

  # Calculate subtotal (before tax)
  def subtotal
    (quantity * price_unit).round(2)
  end

  # Calculate total (including tax)
  def calculated_total
    subtotal + (subtotal * (tax_percent || 0) / 100.0)
  end

  private

  def calculate_subtotal_and_total
    self.price_subtotal = subtotal
    self.price_total = calculated_total
  end
end

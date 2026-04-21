class Invoice < ApplicationRecord
  belongs_to :hotel
  belongs_to :partner, class_name: 'User'
  has_many :invoice_lines, dependent: :destroy

  validates :invoice_number, presence: true, uniqueness: true
  validates :state, inclusion: { 
    in: %w[draft posted paid canceled],
    message: "must be one of: draft, posted, paid, canceled"
  }
  validates :amount_total, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :issue_date, presence: true, if: :posted?

  enum :state, { draft: 'draft', posted: 'posted', paid: 'paid', canceled: 'canceled' }

  scope :by_state, ->(state) { where(state: state) }
  scope :posted, -> { where(state: 'posted') }
  scope :paid, -> { where(state: 'paid') }
  scope :unpaid, -> { where(state: %w[posted draft]).where.not(amount_residual: 0) }
  scope :overdue, -> { where('due_date < ? AND state != ?', Date.today, 'paid') }

  before_save :calculate_totals, if: :will_save_change_to_invoice_lines?

  # Post the invoice (finalize amounts)
  def post!
    transaction do
      calculate_totals
      update!(state: 'posted', issue_date: Date.today)
    end
  end

  # Mark invoice as paid
  def pay!(amount = nil)
    return false unless posted?

    payment_amount = amount || amount_residual
    new_residual = amount_residual - payment_amount

    if new_residual <= 0
      update!(state: 'paid', amount_residual: 0)
    else
      update!(amount_residual: new_residual)
    end
  end

  # Cancel the invoice
  def cancel!
    return false unless draft? || canceled?

    update!(state: 'canceled', amount_residual: 0)
  end

  # Calculate outstanding balance
  def outstanding_balance
    posted? || paid? ? amount_residual : 0.0
  end

  # Get partner's total balance from all invoices
  def self.partner_balance(partner_id)
    where(partner_id: partner_id)
      .where(state: %w[posted paid])
      .sum(:amount_residual)
  end

  private

  def calculate_totals
    self.amount_total = invoice_lines.sum(&:price_total)
    self.amount_residual = posted? ? amount_total : 0.0
  end
end

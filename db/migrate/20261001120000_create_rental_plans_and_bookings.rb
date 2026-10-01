# frozen_string_literal: true
#
# Fitur sewa harian / mingguan / bulanan + cicilan (installment).
class CreateRentalPlansAndBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :rental_plans do |t|
      t.references :facility, null: false, foreign_key: true
      t.integer :host_id, null: false, comment: 'Pemilik properti/fasilitas'
      t.string :name, null: false
      t.text :description
      t.string :period, null: false, default: 'daily', comment: 'daily, weekly, monthly'
      t.decimal :price, precision: 19, scale: 2, null: false, comment: 'Harga per unit periode'
      t.decimal :discount_percent, precision: 5, scale: 2, default: 0.0
      t.integer :min_quantity, default: 1
      t.integer :max_advance_days, default: 365
      t.boolean :active, default: true, null: false

      # Opsi cicilan
      t.boolean :installment_enabled, default: false, null: false
      t.integer :upfront_percent, default: 20, comment: 'Persentase DP untuk cicilan'
      t.integer :installment_count, default: 3, comment: 'Jumlah angsuran'
      t.integer :installment_interval_days, default: 30, comment: 'Interval jatuh tempo antar angsuran'

      t.timestamps
    end

    add_index :rental_plans, [:facility_id, :period]
    add_index :rental_plans, :active
    add_index :rental_plans, :installment_enabled

    create_table :rental_bookings do |t|
      t.references :rental_plan, null: false, foreign_key: true
      t.references :facility, null: false, foreign_key: true
      t.references :property, null: false, foreign_key: true
      t.integer :user_id, null: false, comment: 'Penyewa (guest)'
      t.integer :host_id, null: false, comment: 'Host properti'
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.integer :quantity, default: 1, comment: 'Jumlah unit periode (mis. 2 minggu)'
      t.decimal :price, precision: 19, scale: 2, default: 0.0
      t.decimal :discount, precision: 19, scale: 2, default: 0.0
      t.decimal :discount_percent, precision: 5, scale: 2, default: 0.0
      t.decimal :total_price, precision: 19, scale: 2, default: 0.0
      t.decimal :amount_paid, precision: 19, scale: 2, default: 0.0
      t.decimal :down_payment, precision: 19, scale: 2, default: 0.0
      t.integer :upfront_percent, default: 0
      t.integer :installment_count, default: 0
      t.string :currency, default: 'IDR'
      t.string :status, default: 'pending_payment',
                comment: 'pending_payment, confirmed, active, completed, cancelled_by_guest, cancelled_by_host, rejected'
      t.string :payment_status, default: 'unpaid',
                comment: 'unpaid, down_payment_paid, partially_paid, paid, overdue, refunded'
      t.text :special_requests
      t.string :idempotency_key, null: false
      t.datetime :cancelled_at
      t.text :cancel_reason

      t.timestamps
    end

    add_index :rental_bookings, :idempotency_key, unique: true
    add_index :rental_bookings, [:facility_id, :start_date, :end_date]
    add_index :rental_bookings, [:property_id, :status]
    add_index :rental_bookings, :payment_status

    create_table :rental_installment_plans do |t|
      t.references :rental_booking, null: false, index: { unique: true }, foreign_key: { to_table: :rental_bookings }
      t.references :rental_plan, foreign_key: true
      t.decimal :total_amount, precision: 19, scale: 2, null: false
      t.decimal :down_payment, precision: 19, scale: 2, default: 0.0
      t.decimal :paid_amount, precision: 19, scale: 2, default: 0.0
      t.integer :installment_count, null: false
      t.integer :installment_interval_days, default: 30
      t.date :next_due_date
      t.string :status, default: 'pending', comment: 'pending, active, completed, overdue, cancelled'

      t.timestamps
    end

    add_index :rental_installment_plans, :status
    add_index :rental_installment_plans, :next_due_date

    create_table :rental_installments do |t|
      t.references :rental_installment_plan, null: false, foreign_key: true
      t.integer :number, null: false, comment: 'Nomor angsuran ke-N'
      t.decimal :amount, precision: 19, scale: 2, null: false
      t.decimal :amount_paid, precision: 19, scale: 2, default: 0.0
      t.decimal :late_fee, precision: 19, scale: 2, default: 0.0
      t.date :due_date, null: false
      t.string :status, default: 'pending', comment: 'pending, paid, overdue, failed'
      t.datetime :paid_at
      t.string :payment_method
      t.string :payment_reference

      t.timestamps
    end

    add_index :rental_installments, [:rental_installment_plan_id, :number], unique: true
    add_index :rental_installments, :due_date
    add_index :rental_installments, :status

    create_table :rental_payments do |t|
      t.references :rental_booking, null: false, foreign_key: { to_table: :rental_bookings }
      t.decimal :amount, precision: 19, scale: 2, null: false
      t.string :currency, default: 'IDR', null: false
      t.string :payment_method, default: 'transfer',
                comment: 'transfer, card, qris, virtual_account, cash, other'
      t.string :reference
      t.string :status, default: 'pending', comment: 'pending, succeeded, failed, refunded'
      t.text :failure_reason
      t.string :kind, default: 'installment', comment: 'down_payment, installment, final_payment'
      t.datetime :paid_at
      t.datetime :refunded_at

      t.timestamps
    end

    add_index :rental_payments, :status
    add_index :rental_payments, :kind
  end
end

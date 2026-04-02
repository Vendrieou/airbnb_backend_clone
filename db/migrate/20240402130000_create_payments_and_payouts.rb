class CreatePayments < ActiveRecord::Migration[7.0]
  def change
    create_table :payments do |t|
      t.references :booking, null: false, foreign_key: true
      t.string :stripe_payment_intent_id, index: { unique: true }
      t.string :stripe_charge_id, index: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, default: 'USD', null: false
      t.integer :status, default: 0, null: false # pending, succeeded, failed, refunded
      t.string :payment_method_type # card, apple_pay, google_pay
      t.text :last_four_digits
      t.string :card_brand
      t.datetime :paid_at
      t.datetime :refunded_at
      t.decimal :refund_amount, precision: 10, scale: 2
      t.string :failure_reason
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :payments, :status
    add_index :payments, :created_at

    create_table :payouts do |t|
      t.references :host, null: false, foreign_key: { to_table: :users }
      t.string :stripe_account_id, index: true
      t.string :stripe_payout_id, index: { unique: true }
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, default: 'USD', null: false
      t.integer :status, default: 0, null: false # pending, paid, failed, cancelled
      t.datetime :paid_at
      t.string :failure_reason
      t.references :payment, null: true, foreign_key: true

      t.timestamps
    end

    add_index :payouts, :status
    add_index :payouts, :created_at
  end
end

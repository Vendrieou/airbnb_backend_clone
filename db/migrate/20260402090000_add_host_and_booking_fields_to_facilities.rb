class AddHostAndBookingFieldsToFacilities < ActiveRecord::Migration[8.1]
  def change
    # Add host_id to facilities table
    add_reference :facilities, :host, null: false, foreign_key: { to_table: :users }
    add_index :facilities, [:host_id, :active]
    
    # Add booking policy fields to facilities
    add_column :facilities, :min_advance_booking_hours, :integer, default: 0, comment: 'Minimum hours before booking allowed'
    add_column :facilities, :max_advance_booking_days, :integer, default: 365, comment: 'Maximum days in advance for booking'
    add_column :facilities, :cancellation_policy, :string, default: 'flexible', comment: 'flexible, moderate, strict'
    add_column :facilities, :amenities, :jsonb, default: [], comment: 'List of amenities'
    add_column :facilities, :rules, :jsonb, default: [], comment: 'Booking rules and restrictions'
    
    # Add currency and payment fields to facility_bookings
    add_column :facility_bookings, :currency, :string, default: 'USD'
    add_column :facility_bookings, :payment_status, :string, default: 'unpaid', comment: 'unpaid, paid, refunded, partially_refunded'
    add_column :facility_bookings, :cancelled_at, :datetime
    add_column :facility_bookings, :cancel_reason, :text
    
    # Update status enum values
    remove_column :facility_bookings, :status if column_exists?(:facility_bookings, :status)
    add_column :facility_bookings, :status, :string, default: 'pending_payment', comment: 'pending_payment, confirmed, completed, cancelled_by_guest, cancelled_by_host, rejected'
    
    # Add index for new columns
    add_index :facility_bookings, :payment_status
    add_index :facility_bookings, :cancelled_at
  end
  
  private
  
  def column_exists?(table, column)
    connection.column_exists?(table, column)
  end
end

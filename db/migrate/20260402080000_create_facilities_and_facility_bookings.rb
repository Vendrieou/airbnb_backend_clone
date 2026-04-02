class CreateFacilitiesAndFacilityBookings < ActiveRecord::Migration[8.1]
  def change
    # Create facilities table (similar to tbl_product but for hotel facilities)
    create_table :facilities do |t|
      t.references :property, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :facility_type, null: false, comment: 'spa, sports, wellness, dining, etc'
      t.decimal :price, precision: 19, scale: 2, default: 0.00
      t.decimal :discount_price, precision: 19, scale: 2, default: 0.00
      t.integer :duration_minutes, default: 60, comment: 'Duration of the facility booking'
      t.jsonb :images, default: [], comment: 'Multiple images for the facility'
      t.string :image, comment: 'Primary image'
      t.boolean :active, default: true
      t.integer :max_capacity, default: 1, comment: 'Maximum people per slot'
      t.time :start_time, comment: 'Daily start time'
      t.time :end_time, comment: 'Daily end time'
      t.integer :slot_interval_minutes, default: 60, comment: 'Booking slot interval'
      
      t.timestamps
    end

    add_index :facilities, :property_id
    add_index :facilities, :facility_type
    add_index :facilities, :active
    add_index :facilities, [:property_id, :active]

    # Create facility bookings table (combines tbl_booking and tbl_transaction_detail concepts)
    create_table :facility_bookings do |t|
      t.references :facility, null: false, foreign_key: true
      t.references :property, null: false, foreign_key: true
      t.integer :user_id, null: false, comment: 'Guest who made the booking'
      t.integer :host_id, null: false, comment: 'Property host'
      t.date :booking_date, null: false, comment: 'Date of the facility usage'
      t.time :start_time, null: false, comment: 'Start time of the slot'
      t.time :end_time, null: false, comment: 'End time of the slot'
      t.integer :quantity, default: 1, comment: 'Number of slots/people'
      t.decimal :price, precision: 19, scale: 2, default: 0.00
      t.decimal :discount, precision: 19, scale: 2, default: 0.00
      t.decimal :discount_percent, precision: 5, scale: 2, default: 0.00
      t.decimal :total_price, precision: 19, scale: 2, default: 0.00
      t.string :status, default: 'pending', comment: 'pending, confirmed, completed, cancelled'
      t.boolean :used, default: false, comment: 'Whether the booking has been used'
      t.string :special_requests, comment: 'Special requests from guest'
      t.string :idempotency_key, null: false, comment: 'Prevent duplicate bookings'
      
      t.timestamps
    end

    add_index :facility_bookings, :facility_id
    add_index :facility_bookings, :property_id
    add_index :facility_bookings, :user_id
    add_index :facility_bookings, :host_id
    add_index :facility_bookings, :booking_date
    add_index :facility_bookings, [:property_id, :booking_date]
    add_index :facility_bookings, [:user_id, :booking_date]
    add_index :facility_bookings, :status
    add_index :facility_bookings, :idempotency_key, unique: true
    add_index :facility_bookings, [:facility_id, :booking_date, :start_time]

    # Add constraint to prevent overlapping bookings for same facility and time slot
    enable_extension "btree_gist" unless extension_enabled?("btree_gist")

    execute <<-SQL
      ALTER TABLE facility_bookings
      ADD CONSTRAINT no_overlapping_facility_bookings
      EXCLUDE USING gist (
        facility_id WITH =,
        booking_date WITH =,
        tsrange(
          booking_date + start_time::interval,
          booking_date + end_time::interval
        ) WITH &&
      ) WHERE (status != 'cancelled');
    SQL

    # Create facility reviews table (extends review concept for facilities)
    create_table :facility_reviews do |t|
      t.references :facility, null: false, foreign_key: true
      t.references :facility_booking, null: false, foreign_key: true
      t.integer :user_id, null: false, comment: 'Guest who left the review'
      t.integer :rating, null: false, comment: '1-5 stars'
      t.text :comment
      t.boolean :visible, default: true
      t.boolean :host_responded, default: false
      t.text :host_response
      t.datetime :host_response_at
      
      t.timestamps
    end

    add_index :facility_reviews, :facility_id
    add_index :facility_reviews, :facility_booking_id
    add_index :facility_reviews, :user_id
    add_index :facility_reviews, :rating
    add_index :facility_reviews, :visible

    # Create member points table (from tbl_member_point)
    create_table :member_points do |t|
      t.integer :user_id, null: false
      t.integer :facility_booking_id, null: false
      t.integer :points, null: false
      t.boolean :expired, default: false
      t.date :expires_at
      
      t.timestamps
    end

    add_index :member_points, :user_id
    add_index :member_points, :facility_booking_id
    add_index :member_points, :expired

    # Add columns to existing bookings table for compatibility
    add_column :bookings, :guest_reviewed, :boolean, default: false
    add_column :bookings, :host_reviewed, :boolean, default: false
  end
end

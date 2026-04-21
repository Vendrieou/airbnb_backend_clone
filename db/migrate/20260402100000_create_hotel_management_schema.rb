class CreateHotelManagementSchema < ActiveRecord::Migration[8.0]
  def change
    # Create hotels table
    create_table :hotels do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.text :address
      t.string :city
      t.string :country
      t.string :phone
      t.string :email
      t.boolean :active, default: true, null: false
      
      t.timestamps
    end

    add_index :hotels, :code, unique: true
    add_index :hotels, :active

    # Create hotel_floors table
    create_table :hotel_floors do |t|
      t.references :hotel, null: false, foreign_key: true
      t.integer :floor_number, null: false
      t.string :floor_name
      
      t.timestamps
    end

    add_index :hotel_floors, [:hotel_id, :floor_number], unique: true

    # Create room_types table
    create_table :room_types do |t|
      t.references :hotel, null: false, foreign_key: true
      t.references :floor, foreign_key: { to_table: :hotel_floors }, null: true
      t.string :name, null: false
      t.string :code, null: false
      t.integer :max_adult, default: 1, null: false
      t.integer :max_child, default: 0
      t.decimal :size_sqm, precision: 5, scale: 2
      t.decimal :base_price, precision: 10, scale: 2, default: 0.0
      t.text :description
      t.boolean :active, default: true, null: false
      
      t.timestamps
    end

    add_index :room_types, [:hotel_id, :code], unique: true
    add_index :room_types, :active

    # Create amenities table
    create_table :amenities do |t|
      t.string :name, null: false
      t.string :category # e.g., "bathroom", "tech", "comfort"
      t.string :icon
      t.text :description
      t.boolean :active, default: true, null: false
      
      t.timestamps
    end

    add_index :amenities, :category
    add_index :amenities, :active

    # Create HABTM join table for room_types and amenities
    create_table :amenities_room_types, id: false do |t|
      t.references :amenity, null: false, foreign_key: true
      t.references :room_type, null: false, foreign_key: true
      
      t.timestamps
    end

    add_index :amenities_room_types, [:amenity_id, :room_type_id], unique: true
    add_index :amenities_room_types, :room_type_id

    # Create rooms table (individual room instances)
    create_table :rooms do |t|
      t.references :room_type, null: false, foreign_key: true
      t.references :floor, foreign_key: { to_table: :hotel_floors }, null: true
      t.string :room_number, null: false
      t.string :status, default: 'available' # available, occupied, maintenance, out_of_order
      t.text :notes
      
      t.timestamps
    end

    add_index :rooms, [:room_type_id, :room_number], unique: true
    add_index :rooms, :status

    # Create invoices table
    create_table :invoices do |t|
      t.references :hotel, null: false, foreign_key: true
      t.references :partner, null: false, foreign_key: { to_table: :users }
      t.string :invoice_number, null: false
      t.date :issue_date
      t.date :due_date
      t.decimal :amount_total, precision: 10, scale: 2, default: 0.0
      t.decimal :amount_residual, precision: 10, scale: 2, default: 0.0
      t.string :state, default: 'draft', null: false # draft, posted, paid, canceled
      t.text :notes
      
      t.timestamps
    end

    add_index :invoices, :invoice_number, unique: true
    add_index :invoices, [:hotel_id, :state]
    add_index :invoices, :partner_id
    add_index :invoices, :state

    # Create invoice_lines table
    create_table :invoice_lines do |t|
      t.references :invoice, null: false, foreign_key: true
      t.string :description, null: false
      t.decimal :quantity, precision: 10, scale: 2, default: 1.0
      t.decimal :price_unit, precision: 10, scale: 2, null: false
      t.decimal :price_subtotal, precision: 10, scale: 2, null: false
      t.decimal :tax_percent, precision: 5, scale: 2, default: 0.0
      t.decimal :price_total, precision: 10, scale: 2, null: false
      t.references :room_type, foreign_key: true, null: true
      t.references :room, foreign_key: true, null: true
      
      t.timestamps
    end

    add_index :invoice_lines, :invoice_id
    add_index :invoice_lines, :room_type_id

    # Add constraint to prevent overlapping room bookings (similar to facility_bookings)
    enable_extension "btree_gist" unless extension_enabled?("btree_gist")
  end
end

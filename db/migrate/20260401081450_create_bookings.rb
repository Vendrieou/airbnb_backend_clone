class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings do |t|
      t.references :property, null: false, foreign_key: true
      t.integer :user_id, null: false # Menggunakan integer biasa karena tabel users belum ada di script ini
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :idempotency_key, null: false

      t.timestamps
    end

    add_index :bookings, :idempotency_key, unique: true

    # Perlindungan tingkat akhir agar tidak ada tanggal tumpang tindih untuk properti yang sama
    # Membutuhkan ekstensi btree_gist di PostgreSQL
    enable_extension "btree_gist"
    
    execute <<-SQL
      ALTER TABLE bookings
      ADD CONSTRAINT no_overlapping_bookings
      EXCLUDE USING gist (
        property_id WITH =,
        daterange(start_date, end_date) WITH &&
      );
    SQL
  end
end

class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :property, null: false, foreign_key: true
      t.references :booking, null: false, foreign_key: true
      t.integer :guest_id, null: false
      t.integer :host_id, null: false
      
      # Rating dimensions (1-5 stars)
      t.integer :overall_rating, null: false
      t.integer :cleanliness_rating, null: false
      t.integer :accuracy_rating, null: false
      t.integer :communication_rating, null: false
      t.integer :location_rating, null: false
      t.integer :check_in_rating, null: false
      t.integer :value_rating, null: false
      
      # Review content
      t.text :comment, null: false
      t.boolean :is_guest_review, null: false, default: true
      t.boolean :is_response, null: false, default: false
      t.references :parent_review, foreign_key: { to_table: :reviews }
      
      # Moderation & visibility
      t.boolean :is_visible, null: false, default: false
      t.boolean :is_flagged, null: false, default: false
      t.datetime :flagged_at
      t.string :flag_reason
      
      t.timestamps
      
      t.index [:property_id, :created_at]
      t.index [:guest_id, :created_at]
      t.index [:host_id, :created_at]
      t.index :is_visible
    end
    
    # Add average rating columns to properties for performance
    add_column :properties, :average_rating, :decimal, precision: 3, scale: 2, default: 0.0
    add_column :properties, :review_count, :integer, default: 0, null: false
    
    # Add review status to bookings
    add_column :bookings, :guest_reviewed, :boolean, default: false, null: false
    add_column :bookings, :host_reviewed, :boolean, default: false, null: false
  end
end

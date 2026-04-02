class CreateWishlists < ActiveRecord::Migration[7.0]
  def change
    create_table :wishlists do |t|
      t.string :name, null: false
      t.references :user, null: false, foreign_key: true
      t.boolean :is_default, default: false, null: false
      t.boolean :public, default: false, null: false
      t.string :share_token, index: { unique: true }

      t.timestamps
    end

    add_index :wishlists, [:user_id, :name], unique: true

    create_table :wishlist_items do |t|
      t.references :wishlist, null: false, foreign_key: { on_delete: :cascade }
      t.references :property, null: false, foreign_key: true
      t.integer :position

      t.timestamps
    end

    add_index :wishlist_items, [:wishlist_id, :property_id], unique: true
    add_index :wishlist_items, :position
  end
end

class WishlistItem < ApplicationRecord
  belongs_to :wishlist
  belongs_to :property

  validates :property_id, uniqueness: { scope: :wishlist_id, message: "already exists in this wishlist" }

  acts_as_list scope: :wishlist if defined?(ActsAsList)
end

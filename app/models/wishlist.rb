class Wishlist < ApplicationRecord
  belongs_to :user
  has_many :wishlist_items, -> { order(position: :asc) }, dependent: :destroy
  has_many :properties, through: :wishlist_items

  before_create :generate_share_token
  after_create :set_as_default_if_first

  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :user_id, message: "already exists in your wishlists" }
  validates :share_token, uniqueness: true, allow_nil: true

  scope :default, -> { where(is_default: true) }
  scope :public, -> { where(public: true) }
  scope :with_properties_count, -> { left_joins(:wishlist_items).select('wishlists.*', 'COUNT(wishlist_items.id) as properties_count').group('wishlists.id') }

  def self.find_by_share_token!(token)
    find_by!(share_token: token)
  end

  def add_property(property)
    return if properties.include?(property)
    
    max_position = wishlist_items.maximum(:position) || 0
    wishlist_items.create!(property: property, position: max_position + 1)
  end

  def remove_property(property)
    wishlist_item = wishlist_items.find_by(property: property)
    wishlist_item&.destroy
  end

  def contains_property?(property)
    properties.exists?(property.id)
  end

  private

  def generate_share_token
    self.share_token = SecureRandom.urlsafe_base64(12) if public? && share_token.blank?
  end

  def set_as_default_if_first
    if user.wishlists.count == 1
      update_column(:is_default, true)
    end
  end
end

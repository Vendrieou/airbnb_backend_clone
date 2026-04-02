class WishlistCreator < ApplicationService
  def initialize(user, params)
    @user = user
    @params = params
  end

  def call
    validate_params!
    
    wishlist = user.wishlists.build(wishlist_params)
    
    if wishlist.save
      { success: true, wishlist: wishlist }
    else
      { success: false, errors: wishlist.errors.full_messages }
    end
  rescue => e
    { success: false, errors: [e.message] }
  end

  private

  attr_reader :user, :params

  def validate_params!
    raise "Name is required" unless params[:name].present?
    raise "Name too long (max 100 characters)" if params[:name].length > 100
  end

  def wishlist_params
    params.permit(:name, :public)
  end
end

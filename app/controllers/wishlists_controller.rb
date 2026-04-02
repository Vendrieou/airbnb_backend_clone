class WishlistsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_wishlist, only: [:show, :update, :destroy, :add_property, :remove_property]

  def index
    @wishlists = current_user.wishlists.with_properties_count
    render json: @wishlists, status: :ok
  end

  def show
    render json: @wishlist, status: :ok
  end

  def create
    result = WishlistCreator.new(current_user, wishlist_params).call
    
    if result[:success]
      render json: { wishlist: result[:wishlist] }, status: :created
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  def update
    if @wishlist.update(wishlist_params)
      render json: { wishlist: @wishlist }, status: :ok
    else
      render json: { errors: @wishlist.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @wishlist.destroy
    head :no_content
  end

  def add_property
    property = Property.find(params[:property_id])
    
    if @wishlist.add_property(property)
      render json: { wishlist: @wishlist, message: "Property added to wishlist" }, status: :ok
    else
      render json: { errors: ["Property already in wishlist"] }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ["Property not found"] }, status: :not_found
  end

  def remove_property
    property = Property.find(params[:property_id])
    
    if @wishlist.remove_property(property)
      render json: { wishlist: @wishlist, message: "Property removed from wishlist" }, status: :ok
    else
      render json: { errors: ["Property not in wishlist"] }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ["Property not found"] }, status: :not_found
  end

  def share
    @wishlist.update!(public: true) if !@wishlist.public?
    render json: { 
      share_url: shared_wishlist_url(@wishlist.share_token),
      share_token: @wishlist.share_token 
    }, status: :ok
  end

  private

  def set_wishlist
    @wishlist = current_user.wishlists.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ["Wishlist not found"] }, status: :not_found
  end

  def wishlist_params
    params.require(:wishlist).permit(:name, :public)
  end
end

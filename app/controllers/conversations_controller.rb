class ConversationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation, only: [:show, :mark_as_read, :archive, :unarchive, :block]

  def index
    @conversations = current_user_conversations
      .includes(:last_message, :property, :booking)
      .order(last_message_at: :desc)
    
    render json: @conversations, status: :ok
  end

  def show
    @messages = @conversation.messages
      .includes(:sender)
      .order(created_at: :asc)
      .page(params[:page])
      .per(20)
    
    render json: {
      conversation: @conversation,
      messages: @messages
    }, status: :ok
  end

  def create
    booking = Booking.find(params[:booking_id])
    property = booking.property
    
    # Check if conversation already exists
    @conversation = Conversation.find_by(booking: booking, property: property)
    
    unless @conversation
      @conversation = Conversation.create!(
        booking: booking,
        property: property,
        status: :active
      )
    end
    
    render json: { conversation: @conversation }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ["Booking not found"] }, status: :not_found
  end

  def mark_as_read
    @conversation.mark_as_read_by!(current_user)
    render json: { message: "Conversation marked as read" }, status: :ok
  end

  def archive
    @conversation.update!(status: :archived)
    render json: { conversation: @conversation }, status: :ok
  end

  def unarchive
    @conversation.update!(status: :active)
    render json: { conversation: @conversation }, status: :ok
  end

  def block
    @conversation.update!(status: :blocked)
    render json: { conversation: @conversation }, status: :ok
  end

  private

  def set_conversation
    @conversation = current_user_conversations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ["Conversation not found"] }, status: :not_found
  end

  def current_user_conversations
    Conversation.joins(:booking).where(
      bookings: { guest_id: current_user.id }
    ).or(
      Conversation.joins(property: :host).where(properties: { host_id: current_user.id })
    )
  end
end

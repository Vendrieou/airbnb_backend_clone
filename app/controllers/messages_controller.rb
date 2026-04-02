class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation
  before_action :set_message, only: [:show, :mark_as_read]

  def index
    @messages = @conversation.messages
      .includes(:sender)
      .order(created_at: :asc)
      .page(params[:page])
      .per(20)
    
    render json: { messages: @messages }, status: :ok
  end

  def create
    @message = @conversation.messages.build(message_params)
    @message.sender = current_user
    
    if @message.save
      MessageBroadcaster.new(@message).call
      render json: { message: @message }, status: :created
    else
      render json: { errors: @message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    render json: { message: @message }, status: :ok
  end

  def mark_as_read
    if @message.update(read: true, read_at: Time.current)
      render json: { message: @message }, status: :ok
    else
      render json: { errors: @message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
    
    # Verify user has access to this conversation
    unless conversation_accessible?
      render json: { errors: ["Unauthorized"] }, status: :forbidden
    end
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ["Conversation not found"] }, status: :not_found
  end

  def set_message
    @message = @conversation.messages.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ["Message not found"] }, status: :not_found
  end

  def conversation_accessible?
    @conversation.booking.guest_id == current_user.id ||
    @conversation.property.host_id == current_user.id
  end

  def message_params
    params.require(:message).permit(:body, :message_type)
  end
end

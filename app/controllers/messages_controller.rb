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
    
    render json: { messages: @messages.map { |m| message_json(m) } }, status: :ok
  end

  def create
    @message = @conversation.messages.build(message_params)
    @message.sender = current_user
    
    if @message.save
      MessageBroadcaster.new(@message).call
      render json: { message: message_json(@message) }, status: :created
    else
      render json: { errors: @message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    render json: { message: message_json(@message) }, status: :ok
  end

  def mark_as_read
    if @message.update(read: true, read_at: Time.current)
      @message.apply_delivery_status!('read') if @message.status.to_i < Message::STATUSES[:read]
      render json: { message: message_json(@message.reload) }, status: :ok
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
    params.require(:message).permit(:body, :message_type, :client_message_id)
  end

  def message_json(m)
    {
      id: m.id,
      client_message_id: m.client_message_id,
      conversation_id: m.conversation_id,
      body: m.body,
      message_type: m.message_type,
      sender_id: m.sender_id,
      sender_name: m.sender&.try(:name),
      mine: m.sender_id == current_user.id,
      status: m.status_name,
      read: m.read,
      created_at: m.created_at.iso8601,
    }
  end
end

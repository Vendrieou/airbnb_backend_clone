class ConversationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation, only: [:show, :mark_as_read, :archive, :unarchive, :block, :toggle_whatsapp]

  def index
    @conversations = current_user_conversations
      .includes(:last_message, :property, :booking)
      .order(last_message_at: :desc)

    render json: { conversations: @conversations.map { |c| conversation_json(c) } }, status: :ok
  end

  def show
    @messages = @conversation.messages
      .includes(:sender)
      .order(created_at: :asc)
      .page(params[:page])
      .per(20)

    other = @conversation.other_participant(current_user)
    render json: {
      conversation: conversation_json(@conversation).merge(
        other_participant: {
          id: other&.id,
          name: other&.try(:name),
          phone: other&.try(:phone),
          wa_link: WhatsappGateway.chat_link(other&.try(:phone)),
        }
      ),
      messages: @messages.map { |m| message_json(m) }
    }, status: :ok
  end

  def create
    booking = Booking.find(params[:booking_id])
    property = booking.property

    # Satu percakapan per booking+property (idempotent)
    @conversation = Conversation.find_by(booking: booking, property: property)

    unless @conversation
      @conversation = Conversation.create!(
        booking: booking,
        property: property,
        status: :active
      )
    end

    render json: { conversation: conversation_json(@conversation) }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ["Booking not found"] }, status: :not_found
  end

  def mark_as_read
    @conversation.mark_as_read_by!(current_user)
    ActionCable.server.broadcast(
      "conversation_#{@conversation.id}_channel",
      { type: 'messages.read', by_user_id: current_user.id }
    )
    render json: { message: "Conversation marked as read" }, status: :ok
  end

  # Toggle: apakah salinan pesan juga dikirim ke WhatsApp lawan bicara
  def toggle_whatsapp
    @conversation.update!(whatsapp_enabled: !@conversation.whatsapp_enabled)
    render json: { conversation: conversation_json(@conversation) }, status: :ok
  end

  def archive
    @conversation.update!(status: :archived)
    render json: { conversation: conversation_json(@conversation) }, status: :ok
  end

  def unarchive
    @conversation.update!(status: :active)
    render json: { conversation: conversation_json(@conversation) }, status: :ok
  end

  def block
    @conversation.update!(status: :blocked)
    render json: { conversation: conversation_json(@conversation) }, status: :ok
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

  def conversation_json(c)
    last = c.last_message
    other = begin
      c.other_participant(current_user)
    rescue StandardError
      nil
    end
    {
      id: c.id,
      status: c.status,
      whatsapp_enabled: c.whatsapp_enabled != false,
      last_message_at: c.last_message_at || c.created_at,
      unread_count: c.unread_count_for(current_user),
      property: { id: c.property_id, name: c.property.try(:title) || c.property.try(:name) },
      booking_id: c.booking_id,
      other_participant: { id: other&.id, name: other&.try(:name) },
      last_message: last && { body: last.body.to_s.truncate(80), sender_name: last.sender&.try(:name), created_at: last.created_at },
    }
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
      status: m.status_name, # pending/sent/delivered/read/failed -> centang ala WA
      read: m.read,
      created_at: m.created_at.iso8601,
    }
  end
end

class ConversationChannel < ApplicationCable::Channel
  def subscribed
    @conversation = Conversation.find(params[:id])
    
    if conversation_accessible?
      stream_from "conversation_#{@conversation.id}_channel"
    else
      reject
    end
  rescue ActiveRecord::RecordNotFound
    reject
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def speak(data)
    message = @conversation.messages.build(
      body: data['body'],
      message_type: data['message_type'] || 'text',
      client_message_id: data['client_message_id'],
      sender: current_user
    )
    
    if message.save
      MessageBroadcaster.new(message).call
    else
      transmit({ error: message.errors.full_messages })
    end
  end

  def mark_as_read
    @conversation.mark_as_read_by!(current_user)
    ActionCable.server.broadcast(
      "conversation_#{@conversation.id}_channel",
      { type: 'messages.read', by_user_id: current_user.id }
    )
    transmit({ status: 'read', conversation_id: @conversation.id })
  end

  # Presence / typing indicator ala WhatsApp
  def typing(data)
    ActionCable.server.broadcast(
      "conversation_#{@conversation.id}_channel",
      { type: 'typing', user_id: current_user&.id, user_name: current_user&.try(:name), is_typing: data.fetch('is_typing', true) }
    )
  end

  private

  def conversation_accessible?
    @conversation.booking.guest_id == current_user.id ||
    @conversation.property.host_id == current_user.id
  end
end

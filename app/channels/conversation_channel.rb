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
    transmit({ status: 'read', conversation_id: @conversation.id })
  end

  private

  def conversation_accessible?
    @conversation.booking.guest_id == current_user.id ||
    @conversation.property.host_id == current_user.id
  end
end

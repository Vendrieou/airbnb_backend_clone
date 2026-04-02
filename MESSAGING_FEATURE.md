# Real-time Messaging System with ActionCable

## Overview
Complete two-way messaging system for guest-host communication with real-time updates.

## Database Schema

### Migration: Create Conversations
```ruby
class CreateConversations < ActiveRecord::Migration[7.1]
  def change
    create_table :conversations do |t|
      t.references :property, null: false, foreign_key: true
      t.references :guest, null: false, foreign_key: { to_table: :users }
      t.references :host, null: false, foreign_key: { to_table: :users }
      t.datetime :last_message_at
      t.boolean :archived, default: false

      t.timestamps
    end

    add_index :conversations, [:guest_id, :created_at]
    add_index :conversations, [:host_id, :created_at]
    add_index :conversations, [:property_id, :last_message_at]
  end
end
```

### Migration: Create Messages
```ruby
class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.text :content, null: false
      t.boolean :read, default: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :messages, [:conversation_id, :created_at]
    add_index :messages, [:sender_id, :created_at]
    add_index :messages, [:read, :created_at]
  end
end
```

## Models

### app/models/conversation.rb
```ruby
class Conversation < ApplicationRecord
  belongs_to :property
  belongs_to :guest, class_name: 'User'
  belongs_to :host, class_name: 'User'

  has_many :messages, dependent: :destroy
  has_many :participants, through: :messages, source: :sender

  validates :property_id, uniqueness: { scope: [:guest_id, :host_id] }

  scope :for_user, ->(user) { where(guest_id: user.id).or(where(host_id: user.id)) }
  scope :with_unread, ->(user) { 
    joins(:messages)
      .where(messages: { read: false })
      .where.not(messages: { sender_id: user.id })
      .distinct
  }

  delegate :name, to: :property, prefix: true

  def other_participant(user)
    guest_id == user.id ? host : guest
  end

  def mark_as_read!(user)
    messages.where(read: false).where.not(sender_id: user.id).update_all(read: true, read_at: Time.current)
  end

  def latest_message
    messages.order(created_at: :desc).first
  end

  def unread_count_for(user)
    messages.where(read: false).where.not(sender_id: user.id).count
  end
end
```

### app/models/message.rb
```ruby
class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender, class_name: 'User'

  validates :content, presence: true, length: { maximum: 5000 }

  after_create :update_conversation_timestamp
  after_create :broadcast_message
  after_create :send_notification

  scope :unread, -> { where(read: false) }
  scope :for_conversation, ->(conversation_id) { where(conversation_id: conversation_id).order(created_at: :asc) }

  private

  def update_conversation_timestamp
    conversation.update_column(:last_message_at, created_at)
  end

  def broadcast_message
    ActionCable.server.broadcast(
      "conversation_#{conversation_id}",
      {
        id: id,
        content: content,
        sender_id: sender_id,
        sender_name: sender.name,
        created_at: created_at.iso8601,
        avatar_url: sender.avatar_url
      }
    )
  end

  def send_notification
    return if conversation.other_participant(sender).online?
    
    NotificationJob.perform_later(
      conversation.other_participant(sender),
      "New message from #{sender.name}",
      "You have a new message in your conversation",
      { type: 'message', conversation_id: conversation_id }
    )
  end
end
```

## ActionCable Channel

### app/channels/conversation_channel.rb
```ruby
class ConversationChannel < ApplicationCable::Channel
  def subscribed
    @conversation = Conversation.find(params[:id])
    
    if authorized?
      stream_from "conversation_#{@conversation.id}"
      mark_messages_as_read
    else
      reject
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def speak(data)
    @conversation.messages.create!(
      content: data['content'],
      sender: current_user
    )
  end

  def mark_read
    @conversation.mark_as_read!(current_user)
  end

  private

  def authorized?
    @conversation.guest_id == current_user.id || @conversation.host_id == current_user.id
  end

  def mark_messages_as_read
    @conversation.mark_as_read!(current_user)
  end
end
```

### app/channels/application_cable/connection.rb
```ruby
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      User.find_by(id: cookies.signed[:user_id]) || reject_unauthorized_connection
    end
  end
end
```

## Controllers

### app/controllers/conversations_controller.rb
```ruby
class ConversationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @conversations = Conversation.for_user(current_user)
                                 .includes(:property, :guest, :host, latest_message: :sender)
                                 .order(last_message_at: :desc)
    render json: @conversations, each_serializer: ConversationSerializer
  end

  def show
    @conversation = Conversation.find(params[:id])
    authorize! :view, @conversation
    
    @conversation.mark_as_read!(current_user)
    
    render json: @conversation, serializer: ConversationDetailSerializer
  end

  def create
    property = Property.find(params[:property_id])
    
    @conversation = Conversation.find_or_create_by!(
      property: property,
      guest: current_user,
      host: property.user
    )
    
    render json: @conversation, serializer: ConversationSerializer, status: :created
  end

  private

  def authorize!
    unless @conversation.guest_id == current_user.id || @conversation.host_id == current_user.id
      render json: { error: 'Unauthorized' }, status: :forbidden
    end
  end
end
```

### app/controllers/messages_controller.rb
```ruby
class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation

  def index
    @messages = @conversation.messages
                             .includes(:sender)
                             .order(created_at: :asc)
                             .page(params[:page])
                             .per(30)
    
    render json: @messages, each_serializer: MessageSerializer
  end

  def create
    @message = @conversation.messages.build(
      content: message_params[:content],
      sender: current_user
    )
    
    if @message.save
      render json: @message, serializer: MessageSerializer, status: :created
    else
      render json: { errors: @message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @message = @conversation.messages.find(params[:id])
    
    if @message.update(message_params)
      render json: @message, serializer: MessageSerializer
    else
      render json: { errors: @message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
    authorize! :view, @conversation
  end

  def message_params
    params.require(:message).permit(:content)
  end

  def authorize!
    unless @conversation.guest_id == current_user.id || @conversation.host_id == current_user.id
      render json: { error: 'Unauthorized' }, status: :forbidden
    end
  end
end
```

## Serializers

### app/serializers/conversation_serializer.rb
```ruby
class ConversationSerializer < ActiveModel::Serializer
  attributes :id, :property_id, :property_name, :other_participant, :last_message_at, :unread_count

  has_one :latest_message, serializer: MessagePreviewSerializer

  def property_name
    object.property.name
  end

  def other_participant
    user = object.other_participant(instance_options[:current_user])
    { id: user.id, name: user.name, avatar_url: user.avatar_url }
  end

  def unread_count
    object.unread_count_for(instance_options[:current_user])
  end
end
```

### app/serializers/message_serializer.rb
```ruby
class MessageSerializer < ActiveModel::Serializer
  attributes :id, :content, :sender_id, :sender_name, :sender_avatar, :read, :created_at

  def sender_name
    object.sender.name
  end

  def sender_avatar
    object.sender.avatar_url
  end
end
```

## Frontend JavaScript (React Example)

### app/javascript/channels/conversation_channel.js
```javascript
import consumer from "./consumer"

export default class ConversationChannel {
  constructor(conversationId, callbacks) {
    this.conversationId = conversationId
    this.callbacks = callbacks
    this.subscription = null
  }

  subscribe() {
    this.subscription = consumer.subscriptions.create(
      { channel: "ConversationChannel", id: this.conversationId },
      {
        received: (data) => {
          if (this.callbacks.onMessage) {
            this.callbacks.onMessage(data)
          }
        },
        
        connected: () => {
          if (this.callbacks.onConnected) {
            this.callbacks.onConnected()
          }
        },
        
        disconnected: () => {
          if (this.callbacks.onDisconnected) {
            this.callbacks.onDisconnected()
          }
        }
      }
    )
    
    return this.subscription
  }

  sendMessage(content) {
    if (this.subscription) {
      this.subscription.perform('speak', { content: content })
    }
  }

  markAsRead() {
    if (this.subscription) {
      this.subscription.perform('mark_read')
    }
  }

  unsubscribe() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }
}
```

### app/javascript/components/ConversationList.jsx
```jsx
import React, { useState, useEffect } from 'react'
import ConversationChannel from '../channels/conversation_channel'

const ConversationList = ({ userId }) => {
  const [conversations, setConversations] = useState([])
  const [selectedConversation, setSelectedConversation] = useState(null)

  useEffect(() => {
    fetchConversations()
    
    // Set up polling for new conversations
    const interval = setInterval(fetchConversations, 30000)
    return () => clearInterval(interval)
  }, [])

  const fetchConversations = async () => {
    const response = await fetch('/api/conversations')
    const data = await response.json()
    setConversations(data)
  }

  const selectConversation = (conversation) => {
    setSelectedConversation(conversation)
  }

  return (
    <div className="conversation-list">
      <h2>Messages</h2>
      <ul>
        {conversations.map(conv => (
          <li 
            key={conv.id} 
            onClick={() => selectConversation(conv)}
            className={selectedConversation?.id === conv.id ? 'active' : ''}
          >
            <img src={conv.other_participant.avatar_url} alt="" />
            <div>
              <strong>{conv.other_participant.name}</strong>
              <p>{conv.property_name}</p>
              {conv.latest_message && (
                <span>{conv.latest_message.content}</span>
              )}
              {conv.unread_count > 0 && (
                <span className="badge">{conv.unread_count}</span>
              )}
            </div>
          </li>
        ))}
      </ul>
      
      {selectedConversation && (
        <MessageThread conversation={selectedConversation} userId={userId} />
      )}
    </div>
  )
}

export default ConversationList
```

### app/javascript/components/MessageThread.jsx
```jsx
import React, { useState, useEffect, useRef } from 'react'
import ConversationChannel from '../channels/conversation_channel'

const MessageThread = ({ conversation, userId }) => {
  const [messages, setMessages] = useState([])
  const [newMessage, setNewMessage] = useState('')
  const [channel, setChannel] = useState(null)
  const messagesEndRef = useRef(null)

  useEffect(() => {
    fetchMessages()
    
    const chatChannel = new ConversationChannel(conversation.id, {
      onMessage: (data) => {
        setMessages(prev => [...prev, data])
        scrollToBottom()
      }
    })
    
    const subscription = chatChannel.subscribe()
    setChannel(chatChannel)
    
    // Mark as read when opening
    chatChannel.markAsRead()
    
    return () => {
      chatChannel.unsubscribe()
    }
  }, [conversation.id])

  const fetchMessages = async () => {
    const response = await fetch(`/api/conversations/${conversation.id}/messages`)
    const data = await response.json()
    setMessages(data)
  }

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  const handleSend = async (e) => {
    e.preventDefault()
    if (!newMessage.trim()) return

    try {
      await fetch(`/api/conversations/${conversation.id}/messages`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: { content: newMessage } })
      })
      setNewMessage('')
    } catch (error) {
      console.error('Failed to send message:', error)
    }
  }

  return (
    <div className="message-thread">
      <div className="messages-container">
        {messages.map(msg => (
          <div 
            key={msg.id} 
            className={`message ${msg.sender_id === userId ? 'sent' : 'received'}`}
          >
            <img src={msg.sender_avatar} alt="" />
            <div className="message-content">
              <p>{msg.content}</p>
              <span className="timestamp">
                {new Date(msg.created_at).toLocaleTimeString()}
              </span>
            </div>
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>
      
      <form onSubmit={handleSend} className="message-form">
        <input
          type="text"
          value={newMessage}
          onChange={(e) => setNewMessage(e.target.value)}
          placeholder="Type a message..."
        />
        <button type="submit">Send</button>
      </form>
    </div>
  )
}

export default MessageThread
```

## Routes

### config/routes.rb
```ruby
Rails.application.routes.draw do
  # API routes
  namespace :api do
    resources :conversations, only: [:index, :show, :create] do
      resources :messages, only: [:index, :create]
    end
  end
  
  # ActionCable
  mount ActionCable.server => '/cable'
end
```

## Configuration

### config/cable.yml
```yaml
development:
  adapter: redis
  url: redis://localhost:6379/1

test:
  adapter: test

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
  channel_prefix: airbnb_production
```

### config/environments/production.rb
```ruby
# Action Cable configuration
config.action_cable.url = 'wss://yourdomain.com/cable'
config.action_cable.allowed_request_origins = ['https://yourdomain.com']
```

## Testing

### test/channels/conversation_channel_test.rb
```ruby
require "test_helper"

class ConversationChannelTest < ActionCable::Channel::TestCase
  setup do
    @conversation = conversations(:one)
    @user = users(:guest)
  end

  test "subscribes to valid conversation" do
    stub_connection current_user: @user
    
    subscribe id: @conversation.id
    
    assert subscription.confirmed?
    assert_has_stream "conversation_#{@conversation.id}"
  end

  test "rejects unauthorized subscription" do
    @other_user = users(:other)
    stub_connection current_user: @other_user
    
    subscribe id: @conversation.id
    
    assert subscription.rejected?
  end

  test "receives broadcasted messages" do
    stub_connection current_user: @user
    subscribe id: @conversation.id
    
    @conversation.messages.create!(
      content: "Hello!",
      sender: @conversation.host
    )
    
    assert_has_broadcast "conversation_#{@conversation.id}", { content: "Hello!" }
  end

  test "sends message via perform" do
    stub_connection current_user: @user
    subscribe id: @conversation.id
    
    perform :speak, content: "Hi there!"
    
    assert_equal 1, @conversation.messages.count
    assert_equal "Hi there!", @conversation.messages.last.content
  end
end
```

## Deployment Checklist

- [ ] Install Redis server
- [ ] Configure Redis connection in `config/cable.yml`
- [ ] Set up ActionCable adapter (Redis recommended for production)
- [ ] Configure WebSocket allowed origins
- [ ] Deploy frontend JavaScript components
- [ ] Test real-time messaging in staging
- [ ] Monitor WebSocket connections in production

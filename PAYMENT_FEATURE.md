# Stripe Payment Integration

## Overview
Complete payment processing system with Stripe for booking payments, host payouts, refunds, and subscription management.

## Prerequisites

### Install Stripe Gem
```ruby
# Gemfile
gem 'stripe', '~> 8.0'
```

```bash
bundle install
```

### Environment Variables
```bash
# .env
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

## Database Schema

### Migration: Add Payment Fields to Bookings
```ruby
class AddPaymentToBookings < ActiveRecord::Migration[7.1]
  def change
    add_column :bookings, :stripe_payment_intent_id, :string
    add_column :bookings, :payment_status, :string, default: 'pending'
    add_column :bookings, :amount_cents, :integer
    add_column :bookings, :currency, :string, default: 'usd'
    add_column :bookings, :payment_method_id, :string
    add_column :bookings, :receipt_url, :string
    add_column :bookings, :refunded_amount_cents, :integer, default: 0
    add_column :bookings, :refund_reason, :text
    
    add_index :bookings, :stripe_payment_intent_id
    add_index :bookings, :payment_status
  end
end
```

### Migration: Create Payouts Table
```ruby
class CreatePayouts < ActiveRecord::Migration[7.1]
  def change
    create_table :payouts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :booking, null: false, foreign_key: true
      t.string :stripe_transfer_id
      t.integer :amount_cents
      t.string :currency, default: 'usd'
      t.string :status, default: 'pending'
      t.datetime :paid_at
      t.text :failure_message
      
      t.timestamps
    end
    
    add_index :payouts, :stripe_transfer_id
    add_index :payouts, :status
  end
end
```

### Migration: Create Customer Payment Methods
```ruby
class CreateCustomerPaymentMethods < ActiveRecord::Migration[7.1]
  def change
    create_table :customer_payment_methods do |t|
      t.references :user, null: false, foreign_key: true
      t.string :stripe_payment_method_id
      t.string :card_brand
      t.string :card_last4
      t.integer :card_exp_month
      t.integer :card_exp_year
      t.boolean :default, default: false
      
      t.timestamps
    end
    
    add_index :customer_payment_methods, :stripe_payment_method_id
    add_index :customer_payment_methods, [:user_id, :default]
  end
end
```

## Models

### app/models/booking.rb
```ruby
class Booking < ApplicationRecord
  belongs_to :guest, class_name: 'User'
  belongs_to :property
  
  has_one :payment, dependent: :destroy
  has_many :payouts, dependent: :destroy
  
  validates :payment_status, inclusion: { 
    in: %w[pending requires_action requires_capture requires_confirmation processing succeeded failed canceled] 
  }
  
  scope :with_successful_payments, -> { where(payment_status: 'succeeded') }
  scope :pending_payment, -> { where(payment_status: ['pending', 'requires_action']) }
  
  def total_amount_cents
    (price_per_night * nights).cents
  end
  
  def service_fee_cents
    (total_amount_cents * 0.12).round # 12% service fee
  end
  
  def host_amount_cents
    total_amount_cents - service_fee_cents
  end
  
  def create_payment_intent
    return if stripe_payment_intent_id.present?
    
    intent = Stripe::PaymentIntent.create(
      amount: total_amount_cents,
      currency: currency,
      customer: guest.stripe_customer_id,
      payment_method_types: ['card'],
      metadata: {
        booking_id: id.to_s,
        property_id: property.id.to_s,
        guest_id: guest.id.to_s
      },
      description: "Booking #{id} for #{property.name}"
    )
    
    update!(
      stripe_payment_intent_id: intent.id,
      amount_cents: intent.amount,
      payment_status: intent.status
    )
    
    intent
  end
  
  def confirm_payment(payment_method_id)
    return unless stripe_payment_intent_id.present?
    
    intent = Stripe::PaymentIntent.confirm(
      stripe_payment_intent_id,
      payment_method: payment_method_id
    )
    
    update!(
      payment_status: intent.status,
      payment_method_id: payment_method_id
    )
    
    if intent.status == 'succeeded'
      create_payout
      send_confirmation_emails
    end
    
    intent
  end
  
  def refund(amount_cents = nil, reason = 'requested_by_customer')
    return unless payment_status == 'succeeded'
    
    amount_to_refund = amount_cents || amount_cents
    
    refund = Stripe::Refund.create(
      payment_intent: stripe_payment_intent_id,
      amount: amount_to_refund,
      reason: reason
    )
    
    update!(
      refunded_amount_cents: (refunded_amount_cents || 0) + amount_to_refund,
      refund_reason: reason
    )
    
    if refunded_amount_cents >= amount_cents
      cancel_payouts
      update!(status: 'cancelled')
    end
    
    refund
  end
  
  private
  
  def create_payout
    return unless host_amount_cents > 0
    
    Payout.create!(
      user: property.user,
      booking: self,
      amount_cents: host_amount_cents,
      currency: currency,
      status: 'pending'
    )
  end
  
  def send_confirmation_emails
    BookingConfirmationMailer.with(booking: self).confirmation_email.deliver_later
    HostNotificationMailer.with(booking: self).new_booking_email.deliver_later
  end
  
  def cancel_payouts
    payouts.pending.each do |payout|
      payout.cancel!
    end
  end
end
```

### app/models/user.rb
```ruby
class User < ApplicationRecord
  has_many :customer_payment_methods, dependent: :destroy
  has_many :payouts, dependent: :destroy
  
  attr_accessor :stripe_setup_intent_client_secret
  
  after_create :create_stripe_customer
  
  def stripe_customer_id
    return @stripe_customer_id if defined?(@stripe_customer_id)
    
    @stripe_customer_id = stripe_metadata['customer_id']
    
    unless @stripe_customer_id.present?
      create_stripe_customer
      @stripe_customer_id = stripe_metadata['customer_id']
    end
    
    @stripe_customer_id
  end
  
  def stripe_connected_account_id
    stripe_metadata['connected_account_id']
  end
  
  def is_host?
    stripe_connected_account_id.present?
  end
  
  def create_stripe_customer
    customer = Stripe::Customer.create(
      email: email,
      name: full_name,
      metadata: {
        user_id: id.to_s
      }
    )
    
    update_stripe_metadata('customer_id', customer.id)
    
    customer.id
  end
  
  def create_stripe_connected_account(account_details = {})
    account = Stripe::Account.create(
      type: 'express',
      email: email,
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true }
      },
      business_type: 'individual',
      individual: {
        first_name: account_details[:first_name],
        last_name: account_details[:last_name],
        phone: account_details[:phone],
        dob: {
          day: account_details[:day],
          month: account_details[:month],
          year: account_details[:year]
        },
        address: {
          line1: account_details[:address_line1],
          city: account_details[:city],
          state: account_details[:state],
          postal_code: account_details[:postal_code],
          country: account_details[:country]
        },
        ssn_last_4: account_details[:ssn_last_4]
      },
      tos_acceptance: {
        date: Time.now.to_i,
        ip: request_remote_ip
      },
      metadata: {
        user_id: id.to_s
      }
    )
    
    update_stripe_metadata('connected_account_id', account.id)
    
    account
  end
  
  def get_onboarding_link(return_url:, refresh_url:)
    account_link = Stripe::AccountLink.create(
      account: stripe_connected_account_id,
      refresh_url: refresh_url,
      return_url: return_url,
      type: 'account_onboarding'
    )
    
    account_link.url
  end
  
  def save_payment_method(payment_method_id, set_default: false)
    payment_method = Stripe::PaymentMethod.attach(
      payment_method_id,
      customer: stripe_customer_id
    )
    
    customer_payment_methods.create!(
      stripe_payment_method_id: payment_method.id,
      card_brand: payment_method.card.brand,
      card_last4: payment_method.card.last4,
      card_exp_month: payment_method.card.exp_month,
      card_exp_year: payment_method.card.exp_year,
      default: set_default
    )
    
    if set_default
      customer_payment_methods.where.not(id: id).update_all(default: false)
    end
    
    payment_method
  end
  
  def default_payment_method
    customer_payment_methods.find_by(default: true)
  end
  
  private
  
  def update_stripe_metadata(key, value)
    current_metadata = stripe_metadata || {}
    update!(stripe_metadata: current_metadata.merge(key => value))
  end
  
  def request_remote_ip
    # In a real app, get from request context
    '127.0.0.1'
  end
end
```

### app/models/payout.rb
```ruby
class Payout < ApplicationRecord
  belongs_to :user
  belongs_to :booking
  
  validates :status, inclusion: { 
    in: %w[pending processing paid failed canceled] 
  }
  
  scope :pending, -> { where(status: 'pending') }
  scope :paid, -> { where(status: 'paid') }
  scope :failed, -> { where(status: 'failed') }
  
  def process
    return unless status == 'pending'
    return unless user.stripe_connected_account_id.present?
    
    begin
      transfer = Stripe::Transfer.create(
        amount: amount_cents,
        currency: currency,
        destination: user.stripe_connected_account_id,
        source_transaction: booking.stripe_payment_intent_id,
        metadata: {
          payout_id: id.to_s,
          booking_id: booking.id.to_s
        }
      )
      
      update!(
        stripe_transfer_id: transfer.id,
        status: 'processing'
      )
      
      transfer
    rescue Stripe::StripeError => e
      update!(
        status: 'failed',
        failure_message: e.message
      )
      
      raise e
    end
  end
  
  def cancel!
    return unless status == 'pending'
    
    if stripe_transfer_id.present?
      Stripe::Transfer.cancel(stripe_transfer_id)
    end
    
    update!(status: 'canceled')
  end
  
  def mark_as_paid
    update!(status: 'paid', paid_at: Time.current)
  end
end
```

## Services

### app/services/stripe_payment_service.rb
```ruby
class StripePaymentService
  attr_reader :booking, :user
  
  def initialize(booking, user)
    @booking = booking
    @user = user
  end
  
  def self.create_payment_intent(booking, user)
    new(booking, user).create_payment_intent
  end
  
  def self.confirm_payment(booking, payment_method_id)
    new(booking, booking.guest).confirm_payment(payment_method_id)
  end
  
  def create_payment_intent
    intent = booking.create_payment_intent
    {
      client_secret: intent.client_secret,
      payment_intent_id: intent.id
    }
  end
  
  def confirm_payment(payment_method_id)
    intent = booking.confirm_payment(payment_method_id)
    
    {
      success: intent.status == 'succeeded',
      status: intent.status,
      requires_action: intent.status == 'requires_action'
    }
  end
  
  def setup_intent_for_user
    setup_intent = Stripe::SetupIntent.create(
      customer: user.stripe_customer_id
    )
    
    {
      client_secret: setup_intent.client_secret,
      setup_intent_id: setup_intent.id
    }
  end
end
```

### app/services/payout_service.rb
```ruby
class PayoutService
  def self.process_pending_payouts
    pending_payouts = Payout.pending
    
    pending_payouts.each do |payout|
      begin
        payout.process
      rescue => e
        Rails.logger.error("Failed to process payout #{payout.id}: #{e.message}")
      end
    end
  end
  
  def self.check_transfer_status(transfer_id)
    transfer = Stripe::Transfer.retrieve(transfer_id)
    
    case transfer.status
    when 'paid'
      Payout.find_by(stripe_transfer_id: transfer_id)&.mark_as_paid
    when 'failed'
      Payout.find_by(stripe_transfer_id: transfer_id)&.update!(
        status: 'failed',
        failure_message: transfer.failure_message
      )
    end
    
    transfer
  end
end
```

## Controllers

### app/controllers/api/payments_controller.rb
```ruby
module Api
  class PaymentsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_booking
    
    def create
      authorize! :pay, @booking
      
      result = StripePaymentService.create_payment_intent(@booking, current_user)
      
      render json: {
        client_secret: result[:client_secret],
        payment_intent_id: result[:payment_intent_id]
      }
    end
    
    def confirm
      authorize! :pay, @booking
      
      result = StripePaymentService.new(@booking, current_user)
                                .confirm_payment(params[:payment_method_id])
      
      if result[:success]
        render json: {
          message: 'Payment successful',
          booking: @booking,
          receipt_url: @booking.receipt_url
        }
      elsif result[:requires_action]
        render json: {
          requires_action: true,
          status: result[:status]
        }, status: :requires_action
      else
        render json: {
          error: 'Payment failed',
          status: result[:status]
        }, status: :unprocessable_entity
      end
    end
    
    def refund
      authorize! :refund, @booking
      
      amount = params[:amount_cents] || @booking.amount_cents
      reason = params[:reason] || 'requested_by_customer'
      
      refund = @booking.refund(amount, reason)
      
      render json: {
        message: 'Refund processed',
        refund_id: refund.id,
        amount: refund.amount
      }
    end
    
    private
    
    def set_booking
      @booking = Booking.find(params[:booking_id])
    end
    
    def authorize!
      unless current_user.can?(:pay, @booking) || current_user.admin?
        render json: { error: 'Unauthorized' }, status: :forbidden
      end
    end
  end
end
```

### app/controllers/api/payment_methods_controller.rb
```ruby
module Api
  class PaymentMethodsController < ApplicationController
    before_action :authenticate_user!
    
    def index
      payment_methods = current_user.customer_payment_methods
      render json: payment_methods
    end
    
    def create
      payment_method = current_user.save_payment_method(
        params[:payment_method_id],
        set_default: params[:set_default]
      )
      
      render json: payment_method, status: :created
    end
    
    def destroy
      payment_method = current_user.customer_payment_methods.find(params[:id])
      
      # Detach from Stripe
      Stripe::PaymentMethod.detach(payment_method.stripe_payment_method_id)
      
      payment_method.destroy
      
      head :no_content
    end
    
    def set_default
      payment_method = current_user.customer_payment_methods.find(params[:id])
      
      current_user.customer_payment_methods.update_all(default: false)
      payment_method.update!(default: true)
      
      render json: payment_method
    end
  end
end
```

### app/controllers/api/host_accounts_controller.rb
```ruby
module Api
  class HostAccountsController < ApplicationController
    before_action :authenticate_user!
    
    def create
      unless current_user.is_host?
        current_user.create_stripe_connected_account(
          first_name: params[:first_name],
          last_name: params[:last_name],
          phone: params[:phone],
          day: params[:dob_day],
          month: params[:dob_month],
          year: params[:dob_year],
          address_line1: params[:address_line1],
          city: params[:city],
          state: params[:state],
          postal_code: params[:postal_code],
          country: params[:country],
          ssn_last_4: params[:ssn_last_4]
        )
      end
      
      onboarding_url = current_user.get_onboarding_link(
        return_url: params[:return_url],
        refresh_url: params[:refresh_url]
      )
      
      render json: {
        onboarding_url: onboarding_url,
        connected_account_id: current_user.stripe_connected_account_id
      }
    end
    
    def show
      unless current_user.is_host?
        return render json: { error: 'Host account not created' }, status: :not_found
      end
      
      account = Stripe::Account.retrieve(current_user.stripe_connected_account_id)
      
      render json: {
        charges_enabled: account.charges_enabled,
        payouts_enabled: account.payouts_enabled,
        requirements: account.requirements,
        details_submitted: account.details_submitted
      }
    end
  end
end
```

### app/controllers/webhooks/stripe_controller.rb
```ruby
module Webhooks
  class StripeController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_webhook_signature
    
    def create
      event = Stripe::Event.construct_from(params)
      
      case event.type
      when 'payment_intent.succeeded'
        handle_payment_succeeded(event.data.object)
      when 'payment_intent.payment_failed'
        handle_payment_failed(event.data.object)
      when 'transfer.paid'
        handle_transfer_paid(event.data.object)
      when 'transfer.failed'
        handle_transfer_failed(event.data.object)
      when 'account.updated'
        handle_account_updated(event.data.object)
      end
      
      head :ok
    rescue JSON::ParserError
      head :bad_request
    end
    
    private
    
    def verify_webhook_signature
      payload = request.body.read
      sig_header = request.headers['Stripe-Signature']
      
      begin
        @event = Stripe::Webhook.construct_event(
          payload,
          sig_header,
          ENV['STRIPE_WEBHOOK_SECRET']
        )
      rescue Stripe::SignatureVerificationError
        head :bad_request
      end
    end
    
    def handle_payment_succeeded(payment_intent)
      booking = Booking.find_by(stripe_payment_intent_id: payment_intent.id)
      return unless booking
      
      booking.update!(
        payment_status: 'succeeded',
        receipt_url: payment_intent.charges.data.first&.receipt_url
      )
      
      booking.create_payout
      booking.send_confirmation_emails
    end
    
    def handle_payment_failed(payment_intent)
      booking = Booking.find_by(stripe_payment_intent_id: payment_intent.id)
      return unless booking
      
      booking.update!(payment_status: 'failed')
      
      BookingFailureMailer.with(booking: booking).failure_email.deliver_later
    end
    
    def handle_transfer_paid(transfer)
      payout = Payout.find_by(stripe_transfer_id: transfer.id)
      payout&.mark_as_paid
    end
    
    def handle_transfer_failed(transfer)
      payout = Payout.find_by(stripe_transfer_id: transfer.id)
      payout&.update!(
        status: 'failed',
        failure_message: transfer.failure_message
      )
    end
    
    def handle_account_updated(account)
      user = User.find_by(stripe_metadata: { 'connected_account_id' => account.id })
      return unless user
      
      # Update user's host status based on account capabilities
      user.update!(
        host_verified: account.charges_enabled && account.payouts_enabled
      )
    end
  end
end
```

## Routes

### config/routes.rb
```ruby
Rails.application.routes.draw do
  namespace :api do
    resources :bookings do
      resource :payment, only: [:create, :confirm] do
        post :refund
      end
      
      resources :payment_methods, only: [:index, :create, :destroy] do
        post :set_default
      end
    end
    
    resource :host_account, only: [:create, :show]
  end
  
  namespace :webhooks do
    post 'stripe', to: 'stripe#create'
  end
end
```

## Frontend Integration (React with Stripe Elements)

### app/javascript/components/PaymentForm.jsx
```jsx
import React, { useState, useEffect } from 'react'
import { loadStripe } from '@stripe/stripe-js'
import {
  Elements,
  CardElement,
  useStripe,
  useElements
} from '@stripe/react-stripe-js'

const stripePromise = loadStripe(process.env.REACT_APP_STRIPE_PUBLISHABLE_KEY)

const CheckoutForm = ({ bookingId, onSuccess, onError }) => {
  const stripe = useStripe()
  const elements = useElements()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  const handleSubmit = async (event) => {
    event.preventDefault()
    setLoading(true)

    if (!stripe || !elements) {
      return
    }

    const cardElement = elements.getElement(CardElement)

    // Create payment intent
    const { error: intentError, clientSecret } = await createPaymentIntent()
    
    if (intentError) {
      setError(intentError)
      setLoading(false)
      return
    }

    // Confirm payment
    const { error: confirmError, paymentIntent } = await stripe.confirmCardPayment(
      clientSecret,
      {
        payment_method: {
          card: cardElement,
        }
      }
    )

    if (confirmError) {
      setError(confirmError.message)
      setLoading(false)
      return
    }

    if (paymentIntent.status === 'succeeded') {
      onSuccess(paymentIntent)
    }

    setLoading(false)
  }

  const createPaymentIntent = async () => {
    const response = await fetch(`/api/bookings/${bookingId}/payment`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    })

    const data = await response.json()

    if (!response.ok) {
      return { error: data.error }
    }

    return { clientSecret: data.client_secret }
  }

  return (
    <form onSubmit={handleSubmit} className="payment-form">
      <div className="card-element">
        <CardElement
          options={{
            style: {
              base: {
                fontSize: '16px',
                color: '#424770',
                '::placeholder': {
                  color: '#aab7c4',
                },
              },
              invalid: {
                color: '#9e2146',
              },
            },
          }}
        />
      </div>

      {error && <div className="error-message">{error}</div>}

      <button type="submit" disabled={!stripe || loading} className="pay-button">
        {loading ? 'Processing...' : 'Pay Now'}
      </button>
    </form>
  )
}

const PaymentForm = ({ bookingId, onSuccess, onError }) => {
  return (
    <Elements stripe={stripePromise}>
      <CheckoutForm
        bookingId={bookingId}
        onSuccess={onSuccess}
        onError={onError}
      />
    </Elements>
  )
}

export default PaymentForm
```

### app/javascript/components/HostOnboarding.jsx
```jsx
import React, { useState } from 'react'

const HostOnboarding = ({ userId }) => {
  const [onboardingUrl, setOnboardingUrl] = useState(null)
  const [loading, setLoading] = useState(false)

  const handleCreateAccount = async () => {
    setLoading(true)

    const response = await fetch('/api/host_account', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        first_name: 'John',
        last_name: 'Doe',
        phone: '+1234567890',
        dob_day: 1,
        dob_month: 1,
        dob_year: 1990,
        address_line1: '123 Main St',
        city: 'San Francisco',
        state: 'CA',
        postal_code: '94105',
        country: 'US',
        ssn_last_4: '1234',
        return_url: `${window.location.origin}/host/account/success`,
        refresh_url: `${window.location.origin}/host/account/refresh`
      })
    })

    const data = await response.json()
    setOnboardingUrl(data.onboarding_url)
    setLoading(false)
  }

  return (
    <div className="host-onboarding">
      <h2>Become a Host</h2>
      <p>Connect your bank account to receive payouts</p>

      {!onboardingUrl ? (
        <button onClick={handleCreateAccount} disabled={loading}>
          {loading ? 'Creating Account...' : 'Start Onboarding'}
        </button>
      ) : (
        <a href={onboardingUrl} target="_blank" rel="noopener noreferrer">
          Complete Your Profile
        </a>
      )}
    </div>
  )
}

export default HostOnboarding
```

## Testing

### test/services/stripe_payment_service_test.rb
```ruby
require 'test_helper'

class StripePaymentServiceTest < ActiveSupport::TestCase
  setup do
    @booking = bookings(:one)
    @guest = @booking.guest
  end

  test 'creates payment intent' do
    result = StripePaymentService.create_payment_intent(@booking, @guest)

    assert result[:client_secret].present?
    assert result[:payment_intent_id].present?
    assert_equal @booking.stripe_payment_intent_id, result[:payment_intent_id]
  end

  test 'confirms payment successfully' do
    # Mock Stripe
    Stripe::PaymentIntent.expects(:confirm).returns(
      OpenStruct.new(status: 'succeeded')
    )

    result = StripePaymentService.confirm_payment(@booking, 'pm_test')

    assert result[:success]
    assert_equal 'succeeded', @booking.reload.payment_status
  end
end
```

## Deployment Checklist

- [ ] Set up Stripe account and get API keys
- [ ] Configure webhook endpoints
- [ ] Test in Stripe test mode
- [ ] Implement PCI compliance measures
- [ ] Set up payout schedules
- [ ] Configure tax calculations if needed
- [ ] Test refund flows
- [ ] Monitor webhook delivery
- [ ] Set up fraud detection rules

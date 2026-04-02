class StripeWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_stripe_signature, only: [:create]

  def create
    # Queue the webhook processing to avoid timeout
    StripeWebhookJob.perform_later(params.to_json)
    
    head :ok
  rescue JSON::ParserError => e
    Rails.logger.error "Invalid JSON in Stripe webhook: #{e.message}"
    head :bad_request
  end

  private

  def verify_stripe_signature
    payload = request.body.read
    sig_header = request.headers['Stripe-Signature']
    endpoint_secret = ENV['STRIPE_WEBHOOK_SECRET']

    begin
      event = Stripe::Webhook.construct_event(
        payload, sig_header, endpoint_secret
      )
      
      # Store event for job processing
      params.merge!(event.to_hash)
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid payload in Stripe webhook: #{e.message}"
      head :bad_request
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error "Invalid signature in Stripe webhook: #{e.message}"
      head :unauthorized
    end
  end
end

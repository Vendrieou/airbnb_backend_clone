class StripeWebhookJob < ApplicationJob
  queue_as :default

  retry_on Stripe::APIError, wait: 10.seconds, attempts: 5
  discard_on JSON::ParserError

  def perform(event_data)
    event = Stripe::Event.construct_from(JSON.parse(event_data))
    
    case event.type
    when 'payment_intent.succeeded'
      handle_payment_succeeded(event.data.object)
    when 'payment_intent.payment_failed'
      handle_payment_failed(event.data.object)
    when 'charge.refunded'
      handle_charge_refunded(event.data.object)
    when 'payout.paid'
      handle_payout_paid(event.data.object)
    when 'payout.failed'
      handle_payout_failed(event.data.object)
    else
      Rails.logger.info "Unhandled Stripe event type: #{event.type}"
    end
  rescue => e
    Rails.logger.error "Stripe webhook error: #{e.message}"
    raise e
  end

  private

  def handle_payment_succeeded(payment_intent)
    payment = Payment.find_by(stripe_payment_intent_id: payment_intent.id)
    return unless payment
    
    payment.succeed!
    booking = payment.booking
    booking.confirm! if booking.respond_to?(:confirm!) && booking.pending?
  end

  def handle_payment_failed(payment_intent)
    payment = Payment.find_by(stripe_payment_intent_id: payment_intent.id)
    return unless payment
    
    error_message = payment_intent.last_payment_error&.message || "Payment failed"
    payment.fail!(error_message)
  end

  def handle_charge_refunded(charge)
    payment = Payment.find_by(stripe_charge_id: charge.id)
    return unless payment
    
    payment.refund!
  end

  def handle_payout_paid(payout)
    stripe_payout = Payout.find_by(stripe_payout_id: payout.id)
    stripe_payout&.pay!
  end

  def handle_payout_failed(payout)
    stripe_payout = Payout.find_by(stripe_payout_id: payout.id)
    return unless stripe_payout
    
    error_message = payout.failure_balance_transaction ? "Payout failed" : "Payout failed"
    stripe_payout.fail!(error_message)
  end
end

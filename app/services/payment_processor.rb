class PaymentProcessor < ApplicationService
  def initialize(booking, payment_params)
    @booking = booking
    @payment_params = payment_params
  end

  def call
    validate_booking!
    create_payment_intent
    
    if @payment_intent&.id
      record_payment
      { success: true, payment: @payment, client_secret: @payment_intent.client_secret }
    else
      { success: false, errors: ["Failed to create payment intent"] }
    end
  rescue Stripe::StripeError => e
    { success: false, errors: [e.message] }
  rescue => e
    { success: false, errors: [e.message] }
  end

  def confirm_payment(payment_intent_id)
    payment = Payment.find_by(stripe_payment_intent_id: payment_intent_id)
    return { success: false, errors: ["Payment not found"] } unless payment

    intent = Stripe::PaymentIntent.retrieve(payment_intent_id)
    
    if intent.status == 'succeeded'
      payment.succeed!
      create_payout
      { success: true, payment: payment }
    else
      payment.fail!(intent.last_payment_error&.message || "Payment failed")
      { success: false, errors: ["Payment not succeeded"] }
    end
  rescue Stripe::StripeError => e
    payment&.fail!(e.message)
    { success: false, errors: [e.message] }
  end

  def refund_payment(payment_id, amount = nil)
    payment = Payment.find(payment_id)
    return { success: false, errors: ["Payment not found"] } unless payment
    return { success: false, errors: ["Payment already refunded"] } if payment.refunded?

    refund_amount = amount || payment.amount
    
    refund = Stripe::Refund.create({
      payment_intent: payment.stripe_payment_intent_id,
      amount: (refund_amount * 100).to_i
    })

    payment.refund!(refund_amount)
    { success: true, refund: refund, payment: payment }
  rescue Stripe::StripeError => e
    { success: false, errors: [e.message] }
  end

  private

  attr_reader :booking, :payment_params

  def validate_booking!
    raise "Booking not found" unless booking.present?
    raise "Booking already paid" if booking.payments.succeeded.exists?
  end

  def create_payment_intent
    amount_cents = (booking.total_price * 100).to_i
    
    @payment_intent = Stripe::PaymentIntent.create({
      amount: amount_cents,
      currency: booking.currency || 'usd',
      metadata: {
        booking_id: booking.id,
        property_id: booking.property_id,
        guest_id: booking.guest_id
      },
      automatic_payment_methods: { enabled: true }
    })
  end

  def record_payment
    @payment = booking.payments.create!(
      stripe_payment_intent_id: @payment_intent.id,
      amount: booking.total_price,
      currency: booking.currency || 'USD',
      status: :pending,
      metadata: {
        customer_email: booking.guest&.email
      }
    )
  end

  def create_payout
    return unless booking.property&.host
    
    payout_amount = calculate_payout_amount(booking.total_price)
    
    Payout.create!(
      host: booking.property.host,
      payment: @payment,
      stripe_account_id: booking.property.host.stripe_account_id,
      amount: payout_amount,
      currency: booking.currency || 'USD',
      status: :pending
    )
  end

  def calculate_payout_amount(total)
    platform_fee_rate = ENV.fetch('PLATFORM_FEE_RATE', '0.03').to_f
    total * (1 - platform_fee_rate)
  end
end

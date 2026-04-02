class PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_payment, only: [:show, :refund]

  def create
    booking = Booking.find(params[:booking_id])
    
    # Verify user is the guest
    unless booking.guest_id == current_user.id
      render json: { errors: ["Unauthorized"] }, status: :forbidden
      return
    end
    
    result = PaymentProcessor.new(booking, payment_params).call
    
    if result[:success]
      render json: { 
        payment: result[:payment], 
        client_secret: result[:client_secret] 
      }, status: :created
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ["Booking not found"] }, status: :not_found
  end

  def show
    render json: { payment: @payment }, status: :ok
  end

  def confirm
    result = PaymentProcessor.new(nil, {}).confirm_payment(params[:payment_intent_id])
    
    if result[:success]
      render json: { payment: result[:payment] }, status: :ok
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  def refund
    # Only allow hosts or admins to refund
    unless can_refund?
      render json: { errors: ["Unauthorized"] }, status: :forbidden
      return
    end
    
    amount = params[:amount] ? BigDecimal(params[:amount]) : nil
    result = PaymentProcessor.new(nil, {}).refund_payment(@payment.id, amount)
    
    if result[:success]
      render json: { payment: result[:payment], refund: result[:refund] }, status: :ok
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  def index
    @payments = current_user_payments
      .includes(:booking)
      .order(created_at: :desc)
      .page(params[:page])
      .per(20)
    
    render json: { payments: @payments }, status: :ok
  end

  private

  def set_payment
    @payment = Payment.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ["Payment not found"] }, status: :not_found
  end

  def can_refund?
    @payment.booking.property.host_id == current_user.id ||
    current_user.admin?
  end

  def current_user_payments
    Payment.joins(booking: :guest).where(bookings: { guest_id: current_user.id })
  end

  def payment_params
    params.permit(:payment_method_id, :save_card)
  end
end

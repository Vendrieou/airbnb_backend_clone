# frozen_string_literal: true
#
# Booking sewa harian/mingguan/bulanan + pembayaran cicilan.
class RentalBookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_booking, only: [:show, :cancel, :pay]

  # POST /rental_plans/:rental_plan_id/bookings
  # Params: start_date, end_date, quantity, pay_in_installments, special_requests
  def create
    plan = RentalPlan.find(params[:rental_plan_id])

    result = RentalBookingCreator.new(
      rental_plan: plan,
      guest: current_user,
      start_date: params[:start_date],
      end_date: params[:end_date],
      quantity: params[:quantity].presence || 1,
      pay_in_installments: truthy?(params[:pay_in_installments]),
      special_requests: params[:special_requests],
      idempotency_key: params[:idempotency_key]
    ).call

    if result.success?
      render json: { booking: booking_json(result.booking) }, status: :created
    else
      render json: { errors: result.errors }, status: :unprocessable_entity
    end
  end

  # GET /rental_bookings - daftar sewa milik user (guest atau host)
  def index
    bookings = RentalBooking.where("user_id = :id OR host_id = :id", id: current_user.id)
                           .includes(:rental_plan, :facility, installment_plan: :installments)
                           .order(created_at: :desc)

    bookings = bookings.where(status: params[:status]) if RentalBooking::STATUSES.include?(params[:status])

    render json: { bookings: bookings.map { |b| booking_json(b) } }
  end

  # GET /rental_bookings/:id
  def show
    render json: { booking: booking_json(@booking, detailed: true) }
  end

  # POST /rental_bookings/:id/cancel
  def cancel
    unless @booking.user_id == current_user.id || @booking.host_id == current_user.id
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end

    if %w[completed cancelled_by_guest cancelled_by_host rejected].include?(@booking.status)
      return render json: { error: "Cannot cancel this booking" }, status: :unprocessable_entity
    end

    reason = params[:reason]
    @booking.user_id == current_user.id ? @booking.cancel_by_guest!(reason) : @booking.cancel_by_host!(reason)
    @booking.installment_plan&.update!(status: 'cancelled')

    render json: { booking: booking_json(@booking), message: "Booking cancelled" }
  end

  # POST /rental_bookings/:id/pay
  # Bayar DP / angsuran / pelunasan. Params: amount, payment_method, reference
  def pay
    unless @booking.user_id == current_user.id
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end

    result = RentalInstallmentPayer.new(
      booking: @booking,
      amount: params[:amount],
      payment_method: params[:payment_method] || 'transfer',
      reference: params[:reference]
    ).call

    if result.success?
      render json: {
        payment: payment_json(result.payment),
        booking: booking_json(@booking.reload)
      }
    else
      render json: { errors: result.errors }, status: :unprocessable_entity
    end
  end

  private

  def set_booking
    @booking = RentalBooking.find(params[:id])

    unless @booking.user_id == current_user.id || @booking.host_id == current_user.id
      render json: { error: "Unauthorized" }, status: :unauthorized and return
    end
  end

  def truthy?(value)
    %w[true 1 yes].include?(value.to_s.downcase)
  end

  def booking_json(booking, detailed: false)
    json = {
      id: booking.id,
      rental_plan_id: booking.rental_plan_id,
      facility_id: booking.facility_id,
      period: booking.rental_plan.period,
      start_date: booking.start_date,
      end_date: booking.end_date,
      quantity: booking.quantity,
      total_price: booking.total_price,
      amount_paid: booking.amount_paid,
      remaining_balance: booking.remaining_balance,
      down_payment: booking.down_payment,
      installment_count: booking.installment_count,
      status: booking.status,
      payment_status: booking.payment_status
    }

    if detailed && (plan = booking.installment_plan)
      plan.save_schedule! unless plan.installments.exists?
      json[:installments] = plan.installments.order(:number).map do |i|
        {
          id: i.id,
          number: i.number,
          amount: i.amount,
          amount_paid: i.amount_paid,
          due_date: i.due_date,
          status: i.status,
          paid_at: i.paid_at
        }
      end
    end

    json
  end

  def payment_json(payment)
    {
      id: payment.id,
      amount: payment.amount,
      kind: payment.kind,
      method: payment.payment_method,
      status: payment.status,
      paid_at: payment.paid_at
    }
  end
end

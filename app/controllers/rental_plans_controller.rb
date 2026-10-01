# frozen_string_literal: true
#
# Katalog paket sewa (harian / mingguan / bulanan, opsi cicilan).
class RentalPlansController < ApplicationController
  before_action :authenticate_user!, only: [:create]

  # GET /rental_plans?facility_id=&period=daily|weekly|monthly&installments=true
  def index
    plans = RentalPlan.active.includes(facility: :property)

    plans = plans.where(facility_id: params[:facility_id]) if params[:facility_id].present?
    plans = plans.where(period: params[:period]) if RentalPlan::PERIODS.include?(params[:period])
    plans = plans.with_installments if truthy?(params[:installments])

    render json: {
      rental_plans: plans.map { |plan| plan_json(plan) }
    }
  end

  # GET /rental_plans/:id
  def show
    plan = RentalPlan.find(params[:id])

    render json: { rental_plan: plan_json(plan, detailed: true) }
  end

  # POST /facilities/:facility_id/rental_plans
  # Host membuat paket sewa untuk fasilitasnya.
  def create
    facility = Facility.find(params[:facility_id])

    unless facility.host_id == current_user.id || facility.property.host_id == current_user.id
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end

    plan = RentalPlan.new(plan_params.merge(facility: facility, host: facility.host))

    if plan.save
      render json: { rental_plan: plan_json(plan) }, status: :created
    else
      render json: { errors: plan.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /rental_plans/:id/availability?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
  def availability
    plan = RentalPlan.find(params[:id])
    start_date = Date.parse(params[:start_date].to_s)
    end_date = Date.parse(params[:end_date].to_s)

    available = plan.available_for?(start_date, end_date)
    render json: { available: available }
  rescue InvalidDateRangeError => e
    render json: { available: false, error: e.message }, status: :unprocessable_entity
  rescue ArgumentError
    render json: { error: "Invalid date format" }, status: :unprocessable_entity
  end

  # GET /rental_plans/:id/installment_estimate?start_date=&end_date=&quantity=
  # Preview skema cicilan (DP + jadwal angsuran) tanpa menyimpan apa pun.
  def installment_estimate
    plan = RentalPlan.find(params[:id])

    unless plan.installment_enabled?
      return render json: { error: "Cicilan tidak tersedia untuk paket ini" }, status: :unprocessable_entity
    end

    quantity = (params[:quantity].presence || 1).to_i
    total = plan.total_price_for(quantity)
    estimate = plan.installment_estimate(total)

    render json: {
      rental_plan_id: plan.id,
      period: plan.period,
      quantity: quantity,
      total_price: total,
      down_payment: estimate.down_payment,
      upfront_percent: plan.upfront_percent,
      installment_count: plan.installment_count,
      installments: estimate.installments.map do |i|
        { number: i.number, amount: i.amount, due_date: i.due_date }
      end
    }
  end

  private

  def truthy?(value)
    %w[true 1 yes].include?(value.to_s.downcase)
  end

  def plan_json(plan, detailed: false)
    json = {
      id: plan.id,
      name: plan.name,
      facility_id: plan.facility_id,
      property_id: plan.facility.property_id,
      period: plan.period,
      price: plan.price,
      discount_percent: plan.discount_percent,
      min_quantity: plan.min_quantity,
      installment_enabled: plan.installment_enabled,
      active: plan.active?
    }

    if detailed
      json.merge!(
        description: plan.description,
        max_advance_days: plan.max_advance_days,
        upfront_percent: plan.upfront_percent,
        installment_count: plan.installment_count,
        installment_interval_days: plan.installment_interval_days
      )
    end

    json
  end

  def plan_params
    params.require(:rental_plan).permit(
      :name, :description, :period, :price, :discount_percent,
      :min_quantity, :max_advance_days, :active,
      :installment_enabled, :upfront_percent,
      :installment_count, :installment_interval_days
    )
  end
end

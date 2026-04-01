class BookingsController < ApplicationController
  def create
    idempotency_key = request.headers['Idempotency-Key']
    
    if idempotency_key.blank?
      return render json: { error: 'Idempotency-Key wajib disertakan di header' }, status: :bad_request
    end

    property = Property.find(params[:property_id])
    user_id = 1 # Placeholder ID. Pada implementasi nyata, gunakan current_user.id dari Devise/JWT

    begin
      booking = Booking.create_safe_booking!(
        property,
        user_id,
        params[:start_date],
        params[:end_date],
        idempotency_key
      )

      # Trigger background job
      BookingConfirmationJob.perform_later(booking.id)

      render json: { message: 'Booking berhasil', booking: booking }, status: :created

    rescue ActiveRecord::RecordNotUnique
      render json: { error: 'Permintaan duplikat terdeteksi atau properti tidak tersedia.' }, status: :conflict
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Properti tidak ditemukan' }, status: :not_found
    end
  end
end

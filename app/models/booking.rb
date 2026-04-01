class Booking < ApplicationRecord
  belongs_to :property

  validates :start_date, :end_date, :idempotency_key, presence: true

  def self.create_safe_booking!(property, user_id, start_date, end_date, idempotency_key)
    # Cek Idempotency Key
    existing_booking = find_by(idempotency_key: idempotency_key)
    return existing_booking if existing_booking

    # Pessimistic Locking
    property.with_lock do
      if property.available?(start_date, end_date)
        create!(
          property: property,
          user_id: user_id, # Asumsi auth user
          start_date: start_date,
          end_date: end_date,
          idempotency_key: idempotency_key
        )
      else
        raise ActiveRecord::RecordInvalid, "Properti sudah dipesan pada tanggal tersebut."
      end
    end
  end
end

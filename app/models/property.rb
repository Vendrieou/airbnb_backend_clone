class Property < ApplicationRecord
  has_many :bookings

  def available?(check_in, check_out)
    # Memeriksa ketersediaan (menghindari N+1 jika dipanggil dalam loop, tapi aman di dalam lock)
    bookings.where("start_date < ? AND end_date > ?", check_out, check_in).none?
  end
end

# Notifikasi WhatsApp out-of-app untuk event bisnis penting.
# Dipakai RentalInstallmentPayer / job due-check / housekeeping auto-task.
class WhatsappNotifier
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def self.notify(user, body)
    new(user).notify(body)
  end

  def notify(body)
    return Result.skipped("user tidak punya phone") if phone.blank?
    res = WhatsappGateway.deliver(phone: phone, body: body)
    Rails.logger.info("[WhatsappNotifier] #{res.success ? 'ok' : 'gagal'} -> #{phone}")
    res
  end

  # ---- Template bisnis (Bahasa Indonesia, format chat WA) ----

  def booking_created(booking)
    notify(<<~MSG.strip)
      🏡 *SewaCicil*
      Booking sewa kamu *#{booking.rental_plan.name}* sudah dibuat ✅
      📅 #{booking.start_date} → #{booking.end_date}
      💰 Total: #{idr(booking.total_amount)}
      #{installment_summary(booking)}
      Detail & pembayaran: #{app_url("/bookings/#{booking.id}")}
    MSG
  end

  def installment_due(installment)
    booking = installment.plan.booking
    days = (installment.due_date - Date.current).to_i
    label = days.zero? ? "*hari ini*" : days.negative? ? "*terlambat #{days.abs} hari*" : "dalam #{days} hari"
    notify(<<~MSG.strip)
      🔔 *Pengingat Cicilan — SewaCicil*
      Angsuran ke-#{installment.number}/#{booking.rental_plan.installment_count} sebesar #{idr(installment.amount)} jatuh tempo #{label}.
      Booking: #{booking.rental_plan.name} (#{booking.start_date} → #{booking.end_date})
      Bayar sekarang: #{app_url("/bookings/#{booking.id}")}
    MSG
  end

  def payment_received(booking, amount)
    notify(<<~MSG.strip)
      ✅ *Pembayaran diterima — SewaCicil*
      Pembayaran #{idr(amount)} untuk booking #{booking.rental_plan.name} berhasil.
      Status: #{I18n.t("payment_status.#{booking.payment_status}", default: booking.payment_status.humanize)}
      Terima kasih 🙏
    MSG
  end

  def checkout_task_created(task)
    host = task.board.property&.host || task.board.host
    notify(<<~MSG.strip)
      🧹 *Tugas Housekeeping Baru (auto)*
      Kamar #{task.room_label} checkout dan tidak diperpanjang setelah H-3.
      Task dibuat otomatis di kolom *Draft* pada board Kanban.
      Buka board: #{app_url("/housekeeping")}
    MSG
  end

  private

  def phone
    user.respond_to?(:phone) ? user.phone : user.try(:phone_number)
  end

  def installment_summary(booking)
    plan = booking.rental_installment_plan
    return "💳 Pembayaran penuh (tidak dicicil)." unless plan
    first = booking.rental_installments.order(:number).first
    <<~MSG.strip
      💳 Skema cicilan: DP #{idr(plan.down_payment_amount)}, #{plan.installment_count} angsuran @#{idr(plan.installment_amount)}
      Angsuran pertama jatuh tempo: #{first&.due_date}
    MSG
  end

  def idr(n)
    "Rp#{number_with_delimiter(n.to_i)}"
  end

  def number_with_delimiter(n)
    n.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse
  end

  def app_url(path)
    "#{ENV.fetch('APP_URL', 'http://localhost:5173')}#{path}"
  end

  Result = Struct.new(:success, :error, keyword_init: true) do
    def self.skipped(reason) = new(success: false, error: reason)
  end
end

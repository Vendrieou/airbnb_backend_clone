# Gateway WhatsApp untuk pesan out-of-app (notifikasi booking, cicilan, task housekeeping).
#
# Provider dipilih lewat ENV["WHATSAPP_PROVIDER"]:
#   - "fake" (default dev/test): tidak ada HTTP keluar, cukup log + hasil sukses.
#   - "fonnte": POST https://api.fonnte.com/send (server-to-server, cocok utk notifikasi).
#   - "wablas": POST http://host:port/api/message (self-hosted WA gateway).
#
# Catatan UX: tombol chat in-app memakai wa.me/<nomor>?text=... di browser
# (lihat frontend/src/pages/ChatPage.jsx) — itu tetap bekerja tanpa provider apa pun.
class WhatsappGateway
  Result = Struct.new(:success, :provider_message_id, :error, keyword_init: true)

  class << self
    def deliver(phone:, body:)
      new.deliver(phone: phone, body: body)
    end
  end

  def provider
    ENV.fetch("WHATSAPP_PROVIDER", "fake")
  end

  def deliver(phone:, body:)
    case provider
    when "fonnte" then via_fonnte(phone, body)
    when "wablas" then via_wablas(phone, body)
    else via_fake(phone, body)
    end
  rescue StandardError => e
    Rails.logger.warn("[WhatsappGateway] gagal kirim ke #{phone}: #{e.message}")
    Result.new(success: false, error: e.message)
  end

  # Link klik-untuk-chat (dipakai juga oleh frontend & backend template)
  def self.chat_link(phone, text = nil)
    digits = phone.to_s.gsub(/\D/, "")
    digits = "62#{digits[1..]}" if digits.start_with?("0")
    url = "https://wa.me/#{digits}"
    url += "?text=#{CGI.escape(text)}" if text.present?
    url
  end

  private

  def via_fake(phone, body)
    Rails.logger.info("[WhatsappGateway:fake] -> #{phone}: #{body.to_s.truncate(120)}")
    Result.new(success: true, provider_message_id: "fake-#{SecureRandom.hex(8)}")
  end

  def via_fonnte(phone, body)
    uri = URI("https://api.fonnte.com/send")
    res = Net::HTTP.post_form(uri, {
      "target" => phone.to_s.gsub(/\D/, ""),
      "message" => body,
      "filename" => "",
    }.merge("Authorization" => ENV.fetch("FONNTE_TOKEN", ""))) do |req|
      req['Authorization'] = ENV.fetch("FONNTE_TOKEN", "")
    end
    json = JSON.parse(res.body) rescue {}
    ok = res.is_a?(Net::HTTPSuccess) && json["status"] != false
    Result.new(
      success: ok,
      provider_message_id: Array(json.dig("detail", "id")).first.to_s.presence || Array(json["detail"]).first.to_s,
      error: ok ? nil : json["reason"].to_s,
    )
  end

  def via_wablas(phone, body)
    uri = URI("#{ENV.fetch('WABLAS_URL', 'http://localhost:5000')}/api/message")
    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json",
                              "Authorization" => "key #{ENV.fetch('WABLAS_KEY', '')}")
    req.body = { destination: phone, message: body }.to_json
    res = Net::HTTP.start(uri.hostname, uri.port) { |h| h.request(req) }
    json = JSON.parse(res.body) rescue {}
    Result.new(success: res.code.to_i < 300, provider_message_id: json["id"].to_s, error: json["message"].to_s.presence)
  end
end

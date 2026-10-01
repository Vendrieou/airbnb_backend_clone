class WhatsappWebhooksController < ApplicationController
  # Provider WA mengirim callback status (sent/delivered/read). Tidak butuh login,
  # tapi wajib diberi token agar tidak bisa dipalsukan.
  skip_before_action :authenticate_user!, raise: false

  def create
    return head(:unauthorized) unless valid_token?

    message = Message.find_by(client_message_id: params[:client_message_id]) ||
              Message.find_by(wa_message_id: params[:id].to_s.presence)

    if message
      message.apply_delivery_status!(params[:status].to_s, at: Time.current)
      render json: { ok: true }, status: :ok
    else
      render json: { ok: false, error: "message not found" }, status: :not_found
    end
  end

  private

  def valid_token?
    secret = ENV.fetch("WHATSAPP_WEBHOOK_TOKEN", "dev-whatsapp-token")
    provided = request.headers["X-Whatsapp-Token"] || params[:token]
    ActiveSupport::SecurityUtils.secure_compare(provided.to_s, secret)
  end
end

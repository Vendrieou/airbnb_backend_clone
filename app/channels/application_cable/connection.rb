module ApplicationCable
  class Connection < ActionCable::Server::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      reject_unauthorized_connection unless current_user
    end

    private

    def find_verified_user
      # Get token from query params or headers
      token = request.params[:token] || request.headers['Authorization']&.split(' ')&.last
      
      if token.present?
        begin
          payload = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: 'HS256' })
          user_id = payload[0]['user_id']
          User.find(user_id)
        rescue JWT::DecodeError, ActiveRecord::RecordNotFound
          nil
        end
      end
    end
  end
end

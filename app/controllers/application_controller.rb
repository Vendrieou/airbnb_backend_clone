class ApplicationController < ActionController::API
  include Authentication
  
  rescue_from StandardError, with: :handle_server_error
  
  private
  
  def handle_server_error(exception)
    Rails.logger.error "Server error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    render json: { 
      error: 'Internal server error',
      details: Rails.env.development? ? exception.message : nil
    }, status: :internal_server_error
  end
end

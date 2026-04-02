Rails.application.routes.draw do
  # Portal dashboards for Host and Guest
  namespace :portals do
    get :host_dashboard, to: 'portals#host_dashboard'
    get :guest_dashboard, to: 'portals#guest_dashboard'
  end

  resources :bookings, only: [:create]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end

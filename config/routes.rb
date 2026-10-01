Rails.application.routes.draw do
  # Portal dashboards for Host and Guest
  namespace :portals do
    get :host_dashboard, to: 'portals#host_dashboard'
    get :guest_dashboard, to: 'portals#guest_dashboard'
  end

  # Admin area for facility management
  namespace :admin do
    resources :facilities do
      member do
        get :availability
      end
    end
    
    # Chat ala WhatsApp: percakapan guest <-> host + pesan realtime (ActionCable)
  resources :conversations, only: [:index, :show, :create] do
    member do
      post :mark_as_read
      post :toggle_whatsapp
      post :archive
      post :unarchive
      post :block
    end
    resources :messages, only: [:index, :create, :show] do
      member do
        post :mark_as_read
      end
    end
  end

  # ---- Master Data: floor & unit kamar (grid) + setup smart lock ----
  namespace :master_data do
    resources :hotels, only: [] do
      resources :floors, only: [:index, :create]
      get :grid, on: :member, to: 'rooms#grid'
      resources :rooms, only: [:create]
    end
    resources :floors, only: [:update, :destroy]
    resources :rooms, only: [:show, :update, :destroy] do
      resource :smart_lock, only: [:show], controller: 'smart_locks', as: :smart_lock
      post :smart_lock, to: 'smart_locks#create_or_update', as: :install_smart_lock
    end
    resources :smart_locks, only: [], path: 'smart_locks' do
      member do
        patch :master_config, to: 'smart_locks#update_master_config'
        post :pair
        post :refresh
        post :temporary_keys, to: 'smart_locks#generate_temp_key'
        delete 'temporary_keys/:temp_key_id', to: 'smart_locks#revoke_temp_key'
        post :master_keys, to: 'smart_locks#create_master_key'
        delete 'master_keys/:master_key_id', to: 'smart_locks#revoke_master_key'
      end
    end
  end

  # Callback status pengiriman dari provider WhatsApp (fonnte/wablas/WA Cloud)
  post '/webhooks/whatsapp', to: 'whatsapp_webhooks#create'

  resources :facility_bookings, only: [:index, :show] do
      member do
        post :approve
        post :reject
        post :cancel
      end
    end
  end

  # Property bookings
  resources :bookings, only: [:create]
  
  # Facility bookings (hotel amenities, spa, sports, etc.)
  resources :facilities, only: [:index, :show] do
    resources :bookings, only: [:create], controller: 'facility_bookings'
    resources :reviews, only: [:create], controller: 'facility_reviews'
    resources :rental_plans, only: [:create], controller: 'rental_plans'
  end

  # Rental plans: sewa harian / mingguan / bulanan + opsi cicilan
  resources :rental_plans, only: [:index, :show, :create] do
    member do
      get :availability
      get :installment_estimate
    end
    resources :bookings, only: [:create], controller: 'rental_bookings'
  end

  resources :rental_bookings, only: [:index, :show] do
    member do
      post :cancel
      post :pay
    end
  end

  # Housekeeping: Kanban board (draft -> todo -> in_progress -> review -> done)
  # + task otomatis saat kamar checkout tidak diperpanjang setelah H-3
  namespace :housekeeping do
    resources :boards, only: [:index, :show], controller: 'boards'
    resources :tasks, only: [:index, :show, :create], controller: 'tasks' do
      member do
        patch :move
        post :advance
        post :upload
        patch :assign
        post :cancel
      end
    end
  end
  
  resources :facility_bookings, only: [:index, :show] do
    member do
      post :cancel
    end
  end
  
  # Facility availability API endpoint
  get '/api/facilities/:id/availability', to: 'facilities#availability', as: :facility_availability

  # Swagger / OpenAPI docs (static under public/swagger)
  get '/swagger', to: redirect('/swagger/index.html'), as: :swagger_docs

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end

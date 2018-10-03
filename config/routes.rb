require 'sidekiq/web'

Ahad::Application.routes.draw do
  scope :format => true, :constraints => { :format => 'json' } do
    api vendor_string: "mobileforce", default_version: 3 do

      version 3 do
        cache as: 'v3' do
          resources :sessions, :only => [:create, :destroy]
          post '/sessions/reset_password'
          get '/sessions/rescue_emails'
          resources :checkins, :only => [:create, :update]

          constraints ApiPayedConstraint do
            resources :checkins, :only => [:create, :update, :new]
          end
        end
      end

      version 4 do
        cache as: 'v4' do
          inherit from: 'v3'
          get '/sessions/check_updates' => 'sessions#check_updates'
          resources :orders, except: [:show, :new, :edit]
        end
      end

      version 5 do
        cache as: 'v5' do
          inherit from: 'v4'
          post '/sessions/accept_agreement' => 'sessions#accept_agreement'
          get '/locations/nearby'
          get '/locations/download/:teamlead_id' => 'locations#download', :constraints => { :format => 'zip' }, format: 'zip'
          get '/locations/versions' => 'locations#versions'
          resources :checkin_lites, only: [:create]
          resources :scorecard_statistics, only: [:index]
          get '/scorecard_statistics/chiefs_list' => 'scorecard_statistics#chiefs_list'
          get '/scorecard_statistics/merch_stats' => 'scorecard_statistics#merch_stats'
          get '/locations/:id/report_schema' => 'locations#report_schema'

          resources :photos, only: :show, constraints: { format: 'image' }
          resources :plan_items, only: :index
          resources :lenta_items, only: :index
        end
      end

      version 6 do
        cache as: 'v6' do
          inherit from: 'v5'
          get '/sessions/suspicious_apps' => 'sessions#suspicious_apps'
          get '/locations/events' => 'location_events#index'
          post '/locations/problems' => 'location_problems#create'
          get '/locations/:id/audit_schema' => 'locations#audit_schema'
          get '/checkin_types' => 'checkin_types#index'
          get '/checkin_types/:id' => 'checkin_types#show'
          get '/locations/:id/report_schema' => 'locations#report_schema'
          get '/locations/:id/planogram_images/:planogram_image_id' => 'locations#planogram_images', :constraints => { :format => 'image' }, format: 'image'
        end
      end

      version 7 do
        cache as: 'v7' do
          inherit from: 'v6'
          resources :fi_reports, only: :update
          resources :businesses, only: :index
          scope module: :kpi do
            resource :kpi_content_type, only: :show
            resources :kpi_templates, only: :index do
              resources :location_days, only: :show
              resources :location_months, only: :show
              resources :users, only: :index
              resources :locations, only: :index
            end
          end
        end
      end

      version 8 do
        cache as: 'v8' do
          inherit from: 'v7'
          resources :visits, only: [:create, :update] do
            resources :photos, controller: :visit_photos, only: :create
          end
          resources :locations, only: [:index] do
            get :planned, on: :collection
          end
          resources :questionaries, only: [:index]
          resources :planned_values_sets, only: [:index]
          resources :planogram_images, only: [:index] do
            get :download, on: :member, format: 'image'
          end
        end
      end

      version 9 do
        cache as: 'v9' do
          inherit from: 'v8'

          resources :reports, only: :index
          get '/locations/linked_with_route'
        end
      end

      # NOTE TODO: there are some critical updates to locations#nearby, orders#index, lenta_items#nearby
      # to be done when implementing API v7. check those controllers and views, and also the corresponding task:
      # https://atlantic.atlassian.net/browse/MYS-1071
    end
  end

  namespace :web_api, format: true, constraints: { format: 'json' } do
    namespace :admin do
      resources :photo_exports, only: [:index, :create] do
        collection do
          get :companies
          get :signboards
          get :checkin_types
          get :average_photo_count
        end
      end
    end

    resources :signboards, only: :index
    resources :companies, only: :index
    resources :user_descendants, only: :index
    resources :matrices, only: [:index, :show]
    resources :users, only: :index
    resources :businesses, only: :index


  end

  namespace :orders_api, format: true, constraints: { format: 'json' } do
    namespace :v1 do
      resources :companies, only: :index
      resources :signboards, only: :index
      resources :locations, only: :index
      resources :location_categories, only: :index
      resources :location_types, only: :index
      resources :sessions, only: [] do
        get :validate, on: :collection
      end
    end
  end

  resources :planogram_bundles do
    collection do
      get :locations
    end
  end

  resources :questionaries, except: %i(show update)
  resources :location_questionaries, only: :index do
    collection do
      post :create_array
      post :create_all
      post :destroy_array
      post :destroy_all
      post :change_requirement
    end
  end

  namespace :qlik do
    get :statistics, to: 'statistics#show'
  end

  resources :planograms, except: %i(index show destroy)
  # post 'planograms' => 'planograms#create'
  # post 'planograms/create_array' => 'planograms#create_array'
  post 'planograms/destroy_array' => 'planograms#destroy_array'

  post 'planogram_bundles_locations/create_array' => 'planogram_bundles_locations#create_array'
  post 'planogram_bundles_locations/destroy_array' => 'planogram_bundles_locations#destroy_array'
  post 'planogram_bundles_locations/create_all' => 'planogram_bundles_locations#create_all'

  get '/api_doc/v:version' => 'application#api_doc'
  get '/api_doc' => 'application#api_doc'

  resources :organizations, :only => :update
  #get 'checkins/:id/edit' => 'checkins#edit_1_release'
  resources :checkins, only: [:show]

  # Import routes go here
  resources :ap_uploads do
    member do
      patch :cancel
      patch :submit
    end
    collection do
      get :update_states
    end
  end

  resources :kpi_uploads, except: [:edit, :update, :new]
  resources :uploads

  # Export routes go here
  resources :ap_exports, except: [:edit, :update, :index]
  resources :scorecard_exports, except: [:index, :edit, :update]
  resources :location_events_exports, only: [:show, :new, :create]
  resources :exports, only: [:show]

  resources :scorecards, only: [] do
    collection do
      get :table
    end
  end

  devise_scope :user do
    post 'users/password/reset_by_phone' => 'users/passwords#reset_by_phone', as: 'reset_password_by_phone'
  end

  devise_for :users, :controllers => { :registrations => 'users/registrations', :passwords => "users/passwords" }
  resources :users, except: [:update] do
    collection do
      get :list
    end
    member do
      get :organization
      get :timetable
      put :rerole
      post :reinvite
    end
  end

  namespace :admin do
    get '/observe'              => 'statistics#observe', as: :observe
    resources :users, only: :index do
      collection do
        get :history
      end
      member do
        resource :users_business, only: [:edit, :update]
      end
    end
    post '/play_dummy/:id'      => 'users#play_dummy', as: :play_dummy
    delete '/play_dummy'        => 'users#play_dummy', as: :delete_dummy
    get '/request_clone'        => 'checkin_types#request_clone', as: :request_checkin_type_clone
    post '/process_clone'       => 'checkin_types#process_clone', as: :process_checkin_type_clone

    resources :businesses, except: :destroy do
      resources :mobile_versions, only: [:create, :destroy]
    end
    resources :kpi_templates do
      scope module: :kpi_templates do
        member do
          resource :activity, only: :update
        end
      end
    end

    resources :scorecards, only: [:index, :show] do
      member do
        get :restart
      end
      # resources :exports, except: [:index, :edit, :update], controller: '/scorecard_exports'
    end

    resources :location_events, only: [:index] do
      member do
        get :restart
      end
    end

    resources :scorecard_users, only: [:index, :new] do
      member do
        put :add_scorecard_top
        put :remove_scorecard_top
      end
    end

    resources :photo_exports, only: [:new, :create, :show, :destroy]

    namespace :deferred_jobs do
      resources :delete_teams, only: [:new, :create, :destroy, :show]
    end

    resources :ap_uploads, except: :new do
      member do
        post :reject
        post :start_correcting
        patch :correct
        post :return_to_queue
        get :for_clients
        get :versions, to: 'upload_versions#index'
      end
      collection do
        get :update_states
      end
    end
  end

  get '/progress_status' => 'progress_status#update_statuses', as: :progress_status
  get '/progress_states' => 'progress_status#update_states', as: :progress_states
  delete '/users_list' => 'users#destroy_list', as: :destroy_list
  get "/lenta" => "lenta_items#index", :as => :lenta
  get "/team" => "users#index", :as => :team
  put '/reassign/:id' => 'users#reassign'
  post '/add_subordinate' => 'users#add_subordinate'
  post '/add_chief' => 'users#add_chief'
  get "/settings" => "users#settings"
  patch '/settings' => 'users#update_settings'
  get '/set_profile' => 'users#set_profile'
  patch '/set_profile' => 'users#update_profile'

  resources :locations, except: [:new, :create, :edit, :update] do
    collection do
      get :unassigned
      delete :unassigned, action: :destroy_unassigned_list
      post :destroy_array
    end
  end

  resources :suspicious_apps, only: %i{index create destroy}

  get '/404' => 'errors#not_found'
  get '/500' => 'errors#exception'

  mount Sidekiq::Web => '/sidekiq'
end

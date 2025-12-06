Rails.application.routes.draw do
  root "pages#home"

  # Health check endpoint for monitoring
  get "up" => "rails/health#show", as: :rails_health_check

  resources :trips, except: [ :edit, :update ]
end

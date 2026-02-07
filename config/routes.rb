Rails.application.routes.draw do
  resources :conversations do
    resources :messages, only: [:create]
    member do
      post :stop
      post :replay
      get :status
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "conversations#index"
end

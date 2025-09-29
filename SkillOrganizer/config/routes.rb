Rails.application.routes.draw do
  root "skills#index"

  resources :skills do
    member do
      get :relationships
      get :roadmap
    end
  end

  resources :categories, only: [:index, :show, :new, :create, :edit, :update, :destroy]

  # API routes for AJAX functionality
  namespace :api do
    namespace :v1 do
      resources :skills, only: [:index, :show] do
        collection do
          get :search
        end
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end

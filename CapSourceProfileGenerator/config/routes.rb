Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Home page - profile type selection
  root "home#index"

  # User profile routes (students, teachers, professionals - resume parser)
  get "profiles", to: "resumes#index", as: :profiles
  post "profiles/process", to: "resumes#process_resume", as: :profiles_process
  get "profiles/result", to: "resumes#result", as: :profiles_result
  patch "profiles/update_profile", to: "resumes#update_profile", as: :profiles_update_profile

  # Organization profile routes
  get "organizations", to: "organizations#index", as: :organizations
  post "organizations/process", to: "organizations#process_url", as: :organizations_process
  get "organizations/result", to: "organizations#result", as: :organizations_result
  patch "organizations/update_profile", to: "organizations#update_profile", as: :organizations_update_profile
end

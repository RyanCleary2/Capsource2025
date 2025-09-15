# config/routes.rb

Rails.application.routes.draw do
    root "projects#index"
  
    post "/generate_project",         to: "projects#generate_project"
    post "/generate_scope_from_idea", to: "projects#generate_scope_from_idea"
  end
  
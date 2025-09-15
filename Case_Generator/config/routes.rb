Rails.application.routes.draw do
  root "cases#index"

  post "/generate_case",           to: "cases#generate_case"
  post "/generate_scope_from_idea", to: "cases#generate_scope_from_idea"
end

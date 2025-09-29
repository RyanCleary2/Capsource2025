Rails.application.routes.draw do
  root "plans#index"

  post "/generate_mentorship_plan", to: "plans#generate_mentorship_plan"
  post "/generate_mentorship_plan_from_idea", to: "plans#generate_mentorship_plan_from_idea"
end
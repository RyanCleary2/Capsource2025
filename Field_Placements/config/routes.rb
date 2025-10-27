Rails.application.routes.draw do
  root "field_placement#index"

  # Define a route for generating field placements
  post "/generate_field_placement", to: "field_placement#generate_field_placement"
end

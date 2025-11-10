Rails.application.routes.draw do
  root to: 'field_placement#index'

  post 'generate_field_placement', to: 'field_placement#generate_field_placement', as: :generate_field_placement
  post 'generate_scope_from_idea', to: 'field_placement#generate_scope_from_idea', as: :generate_scope_from_idea
end
# config/initializers/cors.rb

Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins '*'   # you can lock this down to your frontend’s domain
      resource '*',
        headers: :any,
        methods: [:get, :post, :options]
    end
  end
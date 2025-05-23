# config/initializers/openai.rb
require "openai"

OpenAI.configure do |config|
  config.access_token = ENV.fetch("OPENAI_API_KEY")
end

CLIENT = OpenAI::Client.new

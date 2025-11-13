FROM ruby:3.2.2-slim

# Install dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    libpq-dev \
    libvips \
    sqlite3 \
    curl \
    nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /rails

# Set production environment
ENV RAILS_ENV=production \
    BUNDLE_WITHOUT=development:test

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && gem install foreman

# Copy application
COPY . .

# Precompile assets
RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile

# Setup database
RUN bundle exec rails db:prepare

# Expose port
EXPOSE 8080

# Start server and background job workers using foreman
CMD ["foreman", "start", "-f", "Procfile"]

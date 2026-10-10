source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "pg", "~> 1.7"
gem "puma", ">= 5.0"

# Background jobs
gem "sidekiq", "~> 8.1"

# Faster Rails boot
gem "bootsnap", require: false

group :development, :test do
  gem "rspec-rails"

  # Debugging
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  # Security
  gem "bundler-audit", require: false
  gem "brakeman", require: false

  # Code quality
  gem "rubocop-rails-omakase", require: false
end

group :test do
  # Stubs HTTP calls (webhook delivery) and blocks accidental real network access in specs
  gem "webmock"
end
source "https://rubygems.org"

gem "rails", "~> 8.1.3"

# Rails boot performance
gem "bootsnap", require: false

gem "pg", "~> 1.6"
gem "puma", "~> 7.0"
gem "sidekiq", "~> 8.1"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  gem "rspec-rails"

  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end
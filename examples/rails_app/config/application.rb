# frozen_string_literal: true

require "rails"
require "active_support/railtie"

module RailsApp
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.autoload_paths << Rails.root.join("app/structs")
  end
end

# frozen_string_literal: true

require "rails/railtie"

module Dry
  module TypeScript
    class Railtie < Rails::Railtie
      initializer "dry_typescript.setup" do |app|
        app.config.after_initialize do
          next unless Dry::TypeScript.enabled?

          Dry::TypeScript.dirs = [
            Rails.root.join("app", "resources"),
            Rails.root.join("app", "structs")
          ] if Dry::TypeScript.dirs.empty?

          listen_enabled = Dry::TypeScript.listen == true ||
                           (Gem.loaded_specs["listen"] && Dry::TypeScript.listen != false)

          if listen_enabled
            require_relative "listen"
            Dry::TypeScript::Listen.call do
              Rails.application.reloader.reload!
            end
          end
        end
      end

      rake_tasks do
        load File.expand_path("tasks/dry_typescript.rake", __dir__)
      end
    end
  end
end

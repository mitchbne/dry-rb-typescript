# frozen_string_literal: true

module Dry
  module TypeScript
    module StructDiscovery
      class << self
        def discover_structs
          ObjectSpace.each_object(Class).select do |klass|
            klass < Dry::Struct && klass.name && !klass.name.empty? && !klass.name.start_with?("Dry::")
          end
        end

        def eager_load_dirs
          return unless defined?(Rails) && Rails.respond_to?(:autoloaders)

          Dry::TypeScript.dirs.each do |dir|
            expanded = File.expand_path(dir)
            Rails.autoloaders.main.eager_load_dir(expanded) if Dir.exist?(expanded)
          end
        end
      end
    end
  end
end

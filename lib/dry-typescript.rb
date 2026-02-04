# frozen_string_literal: true

require "dry-types"
require "dry-struct"

require_relative "dry/typescript/version"

module Dry
  module TypeScript
    class Error < StandardError; end
  end
end

require_relative "dry/typescript/type_compiler"
require_relative "dry/typescript/config"
require_relative "dry/typescript/struct_discovery"
require_relative "dry/typescript/export_helpers"
require_relative "dry/typescript/type_naming"
require_relative "dry/typescript/file_content_builder"
require_relative "dry/typescript/per_struct_config"
require_relative "dry/typescript/struct_compiler"
require_relative "dry/typescript/struct_methods"
require_relative "dry/typescript/generator"
require_relative "dry/typescript/writer"
require_relative "dry/typescript/freshness_checker"
require_relative "dry/typescript/rake_task"
require_relative "dry/typescript/railtie" if defined?(Rails::Railtie)

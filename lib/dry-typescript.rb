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

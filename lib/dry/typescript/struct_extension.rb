# frozen_string_literal: true

require "dry/typescript"
require_relative "struct_methods"

Dry::Struct.extend(Dry::TypeScript::StructMethods) unless Dry::Struct.respond_to?(:to_typescript)

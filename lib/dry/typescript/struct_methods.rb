# frozen_string_literal: true

module Dry
  module TypeScript
    module StructMethods
      def to_typescript(name: nil, export: false)
        compiler = StructCompiler.new(self, type_name: name, export: export)
        compiler.call
      end
    end
  end
end

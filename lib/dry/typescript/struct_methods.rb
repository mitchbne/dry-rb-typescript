# frozen_string_literal: true

module Dry
  module TypeScript
    module StructMethods
      def to_typescript(name: nil, export_style: nil)
        compiler = StructCompiler.new(self, type_name: name, export_style: export_style)
        compiler.call
      end
    end
  end
end

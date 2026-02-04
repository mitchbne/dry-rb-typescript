# frozen_string_literal: true

module Dry
  module TypeScript
    module ExportHelpers
      def build_import_statement(type_name)
        case Dry::TypeScript.config.export_style
        when :default
          "import #{type_name} from './#{type_name}'"
        else
          "import type { #{type_name} } from './#{type_name}'"
        end
      end

      def build_index_export(type_name)
        case Dry::TypeScript.config.export_style
        when :default
          "export { default as #{type_name} } from './#{type_name}'"
        else
          "export type { #{type_name} } from './#{type_name}'"
        end
      end
    end
  end
end

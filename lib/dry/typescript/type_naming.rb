# frozen_string_literal: true

module Dry
  module TypeScript
    module TypeNaming
      def extract_type_name(struct_class)
        if struct_class.respond_to?(:_typescript_config) && struct_class._typescript_config&.type_name
          return struct_class._typescript_config.type_name
        end

        if Dry::TypeScript.config.type_name_transformer
          Dry::TypeScript.config.type_name_transformer.call(struct_class.name)
        else
          struct_class.name.split("::").last
        end
      end
    end
  end
end

# frozen_string_literal: true

module Dry
  module TypeScript
    module TypeNaming
      def extract_type_name(struct_class)
        if struct_class.respond_to?(:_typescript_config) && struct_class._typescript_config&.type_name
          return struct_class._typescript_config.type_name
        end

        transformers = Dry::TypeScript.config.type_name_transformers
        if transformers.any?
          Transformers.apply(transformers, struct_class.name)
        else
          struct_class.name.split("::").last
        end
      end
    end
  end
end

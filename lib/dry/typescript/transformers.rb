# frozen_string_literal: true

module Dry
  module TypeScript
    module Transformers
      def self.strip_struct_suffix
        ->(name) {
          name
            .delete_suffix("::Struct")
            .split("::")
            .join
        }
      end
    end
  end
end

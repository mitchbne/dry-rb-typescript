# frozen_string_literal: true

module Dry
  module TypeScript
    class StructConfigLayer
      attr_accessor :type_name, :export_style, :null_strategy, :type_mappings,
                    :type_name_transformers, :property_name_transformer

      def initialize
        @type_name = nil
        @export_style = nil
        @null_strategy = nil
        @type_mappings = nil
        @type_name_transformers = nil
        @property_name_transformer = nil
      end

      def to_h
        {
          type_name: @type_name,
          export_style: @export_style,
          null_strategy: @null_strategy,
          type_mappings: @type_mappings,
          type_name_transformers: @type_name_transformers,
          property_name_transformer: @property_name_transformer
        }.compact
      end
    end

    module PerStructConfig
      def typescript_config(&block)
        @_typescript_config ||= StructConfigLayer.new
        block&.call(@_typescript_config)
        @_typescript_config
      end

      def _typescript_config
        @_typescript_config
      end
    end
  end
end

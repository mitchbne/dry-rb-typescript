# frozen_string_literal: true

module Dry
  module TypeScript
    class Config
      VALID_NULL_STRATEGIES = %i[nullable optional nullable_and_optional].freeze

      attr_accessor :output_dir, :export_keyword, :type_name_transformer, :property_name_transformer
      attr_reader :null_strategy

      alias_method :export, :export_keyword
      alias_method :export=, :export_keyword=

      def initialize
        @output_dir = nil
        @null_strategy = :nullable
        @export_keyword = false
        @type_mappings = TypeCompiler::PRIMITIVE_MAP.dup
        @type_name_transformer = nil
        @property_name_transformer = nil
      end

      def null_strategy=(value)
        unless VALID_NULL_STRATEGIES.include?(value)
          raise ArgumentError, "Invalid null_strategy: #{value}. Must be one of: #{VALID_NULL_STRATEGIES.join(", ")}"
        end

        @null_strategy = value
      end

      def type_mappings
        @type_mappings.dup
      end

      def type_mappings=(value)
        @type_mappings = value.dup
      end

      def initialize_copy(source)
        super
        @type_mappings = source.type_mappings.dup
      end

      def merge(overrides)
        duped = dup
        overrides.each do |key, value|
          setter = :"#{key}="
          duped.send(setter, value) if duped.respond_to?(setter)
        end
        duped
      end
    end

    class << self
      def config
        @config ||= Config.new
      end

      def configure
        yield config
      end
    end
  end
end

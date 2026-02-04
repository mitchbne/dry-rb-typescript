# frozen_string_literal: true

module Dry
  module TypeScript
    class Config
      VALID_NULL_STRATEGIES = %i[nullable optional nullable_and_optional].freeze
      VALID_EXPORT_STYLES = %i[named default].freeze

      attr_accessor :output_dir, :type_name_transformers, :property_name_transformer, :dirs, :listen
      attr_reader :null_strategy, :export_style

      def initialize
        @output_dir = nil
        @null_strategy = :nullable
        @export_style = :named
        @type_mappings = TypeCompiler::PRIMITIVE_MAP.dup
        @type_name_transformers = []
        @property_name_transformer = nil
        @dirs = []
        @listen = nil
      end

      def null_strategy=(value)
        unless VALID_NULL_STRATEGIES.include?(value)
          raise ArgumentError, "Invalid null_strategy: #{value}. Must be one of: #{VALID_NULL_STRATEGIES.join(", ")}"
        end

        @null_strategy = value
      end

      def export_style=(value)
        unless VALID_EXPORT_STYLES.include?(value)
          raise ArgumentError, "Invalid export_style: #{value}. Must be one of: #{VALID_EXPORT_STYLES.join(", ")}"
        end

        @export_style = value
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

      def enabled?
        return false if ENV["DISABLE_DRY_TYPESCRIPT"] == "true" || ENV["DISABLE_DRY_TYPESCRIPT"] == "1"

        ENV["RAILS_ENV"] == "development" || ENV["RACK_ENV"] == "development" || ENV["DISABLE_DRY_TYPESCRIPT"] == "false"
      end

      def listen
        config.listen
      end

      def listen=(value)
        config.listen = value
      end

      def dirs
        config.dirs
      end

      def dirs=(value)
        config.dirs = value
      end
    end
  end
end

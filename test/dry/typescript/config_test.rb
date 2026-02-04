# frozen_string_literal: true

require "test_helper"

module Dry
  module TypeScript
    class ConfigTest < Minitest::Test
      def setup
        @original_config = Dry::TypeScript.config.dup
      end

      def teardown
        Dry::TypeScript.instance_variable_set(:@config, @original_config)
      end

      def test_default_config_values
        config = Config.new

        assert_nil config.output_dir
        assert_equal :nullable, config.null_strategy
        assert_equal :named, config.export_style
        assert_kind_of Hash, config.type_mappings
        assert_nil config.type_name_transformer
        assert_nil config.property_name_transformer
      end

      def test_configure_block_sets_values
        Dry::TypeScript.configure do |config|
          config.output_dir = "app/javascript/types"
          config.null_strategy = :optional
          config.export_style = :default
        end

        assert_equal "app/javascript/types", Dry::TypeScript.config.output_dir
        assert_equal :optional, Dry::TypeScript.config.null_strategy
        assert_equal :default, Dry::TypeScript.config.export_style
      end

      def test_custom_type_mappings
        Dry::TypeScript.configure do |config|
          config.type_mappings = config.type_mappings.merge(
            BigDecimal => "string",
            Date => "Date"
          )
        end

        assert_equal "string", Dry::TypeScript.config.type_mappings[BigDecimal]
        assert_equal "Date", Dry::TypeScript.config.type_mappings[Date]
      end

      def test_null_strategy_validation_raises_for_invalid_value
        config = Config.new

        assert_raises(ArgumentError) do
          config.null_strategy = :invalid
        end
      end

      def test_accepts_nullable_strategy
        config = Config.new

        config.null_strategy = :nullable

        assert_equal :nullable, config.null_strategy
      end

      def test_accepts_optional_strategy
        config = Config.new

        config.null_strategy = :optional

        assert_equal :optional, config.null_strategy
      end

      def test_accepts_nullable_and_optional_strategy
        config = Config.new

        config.null_strategy = :nullable_and_optional

        assert_equal :nullable_and_optional, config.null_strategy
      end

      def test_type_name_transformer_transforms_names
        Dry::TypeScript.configure do |config|
          config.type_name_transformer = ->(name) { "#{name}DTO" }
        end

        result = Dry::TypeScript.config.type_name_transformer.call("User")

        assert_equal "UserDTO", result
      end

      def test_property_name_transformer_transforms_names
        Dry::TypeScript.configure do |config|
          config.property_name_transformer = ->(name) { name.to_s.upcase }
        end

        result = Dry::TypeScript.config.property_name_transformer.call("first_name")

        assert_equal "FIRST_NAME", result
      end

      def test_dup_creates_independent_copy
        config = Config.new
        config.output_dir = "original"
        config.type_mappings[Date] = "Date"

        duped = config.dup
        duped.output_dir = "duped"
        duped.type_mappings[Range] = "Range"

        assert_equal "original", config.output_dir
        assert_equal "duped", duped.output_dir
        refute config.type_mappings.key?(Range)
      end

      def test_merge_applies_overrides
        base = Config.new
        base.output_dir = "base_dir"
        base.null_strategy = :nullable
        overrides = { output_dir: "override_dir", export_style: :default }

        merged = base.merge(overrides)

        assert_equal "override_dir", merged.output_dir
        assert_equal :nullable, merged.null_strategy
        assert_equal :default, merged.export_style
      end

      def test_export_style_validation_raises_for_invalid_value
        config = Config.new

        assert_raises(ArgumentError) do
          config.export_style = :invalid
        end
      end

      def test_accepts_named_export_style
        config = Config.new

        config.export_style = :named

        assert_equal :named, config.export_style
      end

      def test_accepts_default_export_style
        config = Config.new

        config.export_style = :default

        assert_equal :default, config.export_style
      end

      def test_type_mappings_returns_copy_to_prevent_mutation
        config = Config.new

        mappings = config.type_mappings
        mappings[Range] = "Range"

        refute config.type_mappings.key?(Range)
      end
    end

    class TypeCompilerWithConfigTest < Minitest::Test
      def teardown
        Dry::TypeScript.instance_variable_set(:@config, Config.new)
      end

      def test_uses_global_type_mappings
        Dry::TypeScript.configure do |config|
          config.type_mappings = config.type_mappings.merge(Date => "Date")
        end
        compiler = TypeCompiler.new
        type = Dry::Types["date"]

        result = compiler.call(type)

        assert_equal "Date", result
      end

      def test_local_primitive_map_overrides_global
        Dry::TypeScript.configure do |config|
          config.type_mappings = config.type_mappings.merge(Date => "Date")
        end
        custom_map = TypeCompiler::PRIMITIVE_MAP.merge(Date => "string")
        compiler = TypeCompiler.new(primitive_map: custom_map)
        type = Dry::Types["date"]

        result = compiler.call(type)

        assert_equal "string", result
      end
    end

    class StructCompilerWithConfigTest < Minitest::Test
      module Types
        include Dry.Types
      end

      class ConfigTestUser < Dry::Struct
        attribute :name, Types::String
        attribute :email, Types::String.optional
      end

      def teardown
        Dry::TypeScript.instance_variable_set(:@config, Config.new)
      end

      def test_named_export_style_outputs_export_type
        Dry::TypeScript.configure do |config|
          config.export_style = :named
        end
        compiler = StructCompiler.new(ConfigTestUser)

        result = compiler.call

        assert_match(/^export type ConfigTestUser/, result[:typescript])
      end

      def test_default_export_style_outputs_export_default
        Dry::TypeScript.configure do |config|
          config.export_style = :default
        end
        compiler = StructCompiler.new(ConfigTestUser)

        result = compiler.call

        assert_includes result[:typescript], "type ConfigTestUser"
        assert_includes result[:typescript], "export default ConfigTestUser"
      end

      def test_export_style_option_overrides_config
        Dry::TypeScript.configure do |config|
          config.export_style = :named
        end
        compiler = StructCompiler.new(ConfigTestUser, export_style: :default)

        result = compiler.call

        assert_includes result[:typescript], "export default ConfigTestUser"
      end

      def test_null_strategy_nullable_outputs_union
        Dry::TypeScript.configure do |config|
          config.null_strategy = :nullable
        end
        compiler = StructCompiler.new(ConfigTestUser)

        result = compiler.call

        assert_includes result[:typescript], "email: string | null;"
      end

      def test_null_strategy_optional_outputs_question_mark
        Dry::TypeScript.configure do |config|
          config.null_strategy = :optional
        end
        compiler = StructCompiler.new(ConfigTestUser)

        result = compiler.call

        assert_includes result[:typescript], "email?: string;"
      end

      def test_null_strategy_nullable_and_optional_outputs_both
        Dry::TypeScript.configure do |config|
          config.null_strategy = :nullable_and_optional
        end
        compiler = StructCompiler.new(ConfigTestUser)

        result = compiler.call

        assert_includes result[:typescript], "email?: string | null;"
      end

      def test_type_name_transformer_applies_to_output
        Dry::TypeScript.configure do |config|
          config.type_name_transformer = ->(name) { "#{name.split("::").last}Response" }
        end
        compiler = StructCompiler.new(ConfigTestUser)

        result = compiler.call

        assert_match(/^export type ConfigTestUserResponse = \{/, result[:typescript])
      end

      def test_type_name_option_overrides_transformer
        Dry::TypeScript.configure do |config|
          config.type_name_transformer = ->(name) { "#{name.split("::").last}Response" }
        end
        compiler = StructCompiler.new(ConfigTestUser, type_name: "CustomName")

        result = compiler.call

        assert_match(/^export type CustomName = \{/, result[:typescript])
      end

      def test_property_name_transformer_applies_to_properties
        Dry::TypeScript.configure do |config|
          config.property_name_transformer = ->(name) { name.to_s.upcase }
        end
        compiler = StructCompiler.new(ConfigTestUser)

        result = compiler.call

        assert_includes result[:typescript], "NAME: string;"
        assert_includes result[:typescript], "EMAIL"
      end

      class UserWithConfig < Dry::Struct
        extend Dry::TypeScript::StructMethods
        extend Dry::TypeScript::PerStructConfig

        typescript_config do |config|
          config.type_name = "UserResponse"
          config.export_style = :named
        end

        attribute :name, Types::String
      end

      class UserWithNullConfig < Dry::Struct
        extend Dry::TypeScript::StructMethods
        extend Dry::TypeScript::PerStructConfig

        typescript_config do |config|
          config.null_strategy = :optional
        end

        attribute :name, Types::String
        attribute :bio, Types::String.optional
      end

      def test_per_struct_type_name_override
        Dry::TypeScript.instance_variable_set(:@config, Config.new)

        result = UserWithConfig.to_typescript

        assert_match(/^export type UserResponse = \{/, result[:typescript])
      end

      def test_per_struct_null_strategy_override
        Dry::TypeScript.configure do |config|
          config.null_strategy = :nullable
        end

        result = UserWithNullConfig.to_typescript

        assert_includes result[:typescript], "bio?: string;"
      end

      def test_config_snapshot_isolation
        Dry::TypeScript.configure do |config|
          config.export_style = :default
        end
        compiler = StructCompiler.new(ConfigTestUser)
        Dry::TypeScript.configure do |config|
          config.export_style = :named
        end

        result = compiler.call

        assert_includes result[:typescript], "export default ConfigTestUser"
      end
    end
  end
end

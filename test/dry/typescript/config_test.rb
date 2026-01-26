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
        assert_equal false, config.export_keyword
        assert_kind_of Hash, config.type_mappings
        assert_nil config.type_name_transformer
        assert_nil config.property_name_transformer
      end

      def test_configure_block
        Dry::TypeScript.configure do |config|
          config.output_dir = "app/javascript/types"
          config.null_strategy = :optional
          config.export_keyword = true
        end

        assert_equal "app/javascript/types", Dry::TypeScript.config.output_dir
        assert_equal :optional, Dry::TypeScript.config.null_strategy
        assert_equal true, Dry::TypeScript.config.export_keyword
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

      def test_null_strategy_validation
        config = Config.new

        assert_raises(ArgumentError) do
          config.null_strategy = :invalid
        end
      end

      def test_valid_null_strategies
        config = Config.new

        config.null_strategy = :nullable
        assert_equal :nullable, config.null_strategy

        config.null_strategy = :optional
        assert_equal :optional, config.null_strategy

        config.null_strategy = :nullable_and_optional
        assert_equal :nullable_and_optional, config.null_strategy
      end

      def test_type_name_transformer
        Dry::TypeScript.configure do |config|
          config.type_name_transformer = ->(name) { "#{name}DTO" }
        end

        result = Dry::TypeScript.config.type_name_transformer.call("User")
        assert_equal "UserDTO", result
      end

      def test_property_name_transformer
        Dry::TypeScript.configure do |config|
          config.property_name_transformer = ->(name) { name.to_s.upcase }
        end

        result = Dry::TypeScript.config.property_name_transformer.call("first_name")
        assert_equal "FIRST_NAME", result
      end

      def test_config_dup
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

      def test_merge_config
        base = Config.new
        base.output_dir = "base_dir"
        base.null_strategy = :nullable

        overrides = { output_dir: "override_dir", export_keyword: true }
        merged = base.merge(overrides)

        assert_equal "override_dir", merged.output_dir
        assert_equal :nullable, merged.null_strategy
        assert_equal true, merged.export_keyword
      end

      def test_export_alias
        config = Config.new

        config.export = true
        assert_equal true, config.export
        assert_equal true, config.export_keyword

        config.export_keyword = false
        assert_equal false, config.export
      end

      def test_type_mappings_returns_copy
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

      def test_type_compiler_uses_global_type_mappings
        Dry::TypeScript.configure do |config|
          config.type_mappings = config.type_mappings.merge(Date => "Date")
        end

        compiler = TypeCompiler.new
        type = Dry::Types["date"]
        assert_equal "Date", compiler.call(type)
      end

      def test_type_compiler_local_overrides_global
        Dry::TypeScript.configure do |config|
          config.type_mappings = config.type_mappings.merge(Date => "Date")
        end

        custom_map = TypeCompiler::PRIMITIVE_MAP.merge(Date => "string")
        compiler = TypeCompiler.new(primitive_map: custom_map)
        type = Dry::Types["date"]
        assert_equal "string", compiler.call(type)
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

      def test_struct_compiler_uses_export_keyword_from_config
        Dry::TypeScript.configure do |config|
          config.export_keyword = true
        end

        compiler = StructCompiler.new(ConfigTestUser)
        result = compiler.call

        assert_match(/^export type ConfigTestUser/, result[:typescript])
      end

      def test_struct_compiler_export_option_overrides_config
        Dry::TypeScript.configure do |config|
          config.export_keyword = true
        end

        compiler = StructCompiler.new(ConfigTestUser, export: false)
        result = compiler.call

        refute_match(/^export/, result[:typescript])
      end

      def test_null_strategy_nullable
        Dry::TypeScript.configure do |config|
          config.null_strategy = :nullable
        end

        compiler = StructCompiler.new(ConfigTestUser)
        result = compiler.call

        assert_includes result[:typescript], "email: string | null;"
      end

      def test_null_strategy_optional
        Dry::TypeScript.configure do |config|
          config.null_strategy = :optional
        end

        compiler = StructCompiler.new(ConfigTestUser)
        result = compiler.call

        assert_includes result[:typescript], "email?: string;"
      end

      def test_null_strategy_nullable_and_optional
        Dry::TypeScript.configure do |config|
          config.null_strategy = :nullable_and_optional
        end

        compiler = StructCompiler.new(ConfigTestUser)
        result = compiler.call

        assert_includes result[:typescript], "email?: string | null;"
      end

      def test_type_name_transformer
        Dry::TypeScript.configure do |config|
          config.type_name_transformer = ->(name) { "#{name}Response" }
        end

        compiler = StructCompiler.new(ConfigTestUser)
        result = compiler.call

        assert_match(/^type ConfigTestUserResponse = \{/, result[:typescript])
      end

      def test_type_name_option_overrides_transformer
        Dry::TypeScript.configure do |config|
          config.type_name_transformer = ->(name) { "#{name}Response" }
        end

        compiler = StructCompiler.new(ConfigTestUser, type_name: "CustomName")
        result = compiler.call

        assert_match(/^type CustomName = \{/, result[:typescript])
      end

      def test_property_name_transformer
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
          config.export = true
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
          config.export_keyword = false
        end

        compiler = StructCompiler.new(ConfigTestUser)

        Dry::TypeScript.configure do |config|
          config.export_keyword = true
        end

        result = compiler.call
        refute_match(/^export/, result[:typescript])
      end
    end
  end
end

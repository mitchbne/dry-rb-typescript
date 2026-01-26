# frozen_string_literal: true

require "test_helper"

module Dry
  module TypeScript
    class TypeCompilerTest < Minitest::Test
      def setup
        @compiler = TypeCompiler.new
      end

      # Primitive mapping tests
      def test_string_type
        type = Dry::Types["string"]
        assert_equal "string", @compiler.call(type)
      end

      def test_integer_type
        type = Dry::Types["integer"]
        assert_equal "number", @compiler.call(type)
      end

      def test_float_type
        type = Dry::Types["float"]
        assert_equal "number", @compiler.call(type)
      end

      def test_bool_type
        type = Dry::Types["bool"]
        assert_equal "boolean", @compiler.call(type)
      end

      def test_nil_type
        type = Dry::Types["nil"]
        assert_equal "null", @compiler.call(type)
      end

      def test_date_type
        type = Dry::Types["date"]
        assert_equal "string", @compiler.call(type)
      end

      def test_time_type
        type = Dry::Types["time"]
        assert_equal "string", @compiler.call(type)
      end

      def test_date_time_type
        type = Dry::Types["date_time"]
        assert_equal "string", @compiler.call(type)
      end

      # Optional types (Sum with nil)
      def test_optional_string
        type = Dry::Types["string"].optional
        assert_equal "string | null", @compiler.call(type)
      end

      def test_optional_integer
        type = Dry::Types["integer"].optional
        assert_equal "number | null", @compiler.call(type)
      end

      # Array types
      def test_array_of_strings
        type = Dry::Types["array"].of(Dry::Types["string"])
        assert_equal "string[]", @compiler.call(type)
      end

      def test_array_of_integers
        type = Dry::Types["array"].of(Dry::Types["integer"])
        assert_equal "number[]", @compiler.call(type)
      end

      def test_optional_array_of_integers
        type = Dry::Types["array"].of(Dry::Types["integer"]).optional
        assert_equal "number[] | null", @compiler.call(type)
      end

      # Union types
      def test_union_string_or_integer
        type = Dry::Types["string"] | Dry::Types["integer"]
        assert_equal "string | number", @compiler.call(type)
      end

      def test_union_multiple_types
        type = Dry::Types["string"] | Dry::Types["integer"] | Dry::Types["bool"]
        assert_equal "string | number | boolean", @compiler.call(type)
      end

      # Constrained types (unwrap decorator)
      def test_constrained_integer
        type = Dry::Types["integer"].constrained(gt: 0)
        assert_equal "number", @compiler.call(type)
      end

      def test_constrained_string
        type = Dry::Types["string"].constrained(min_size: 1)
        assert_equal "string", @compiler.call(type)
      end

      def test_constrained_optional
        type = Dry::Types["string"].constrained(min_size: 1).optional
        assert_equal "string | null", @compiler.call(type)
      end

      # Edge cases identified by Oracle review

      def test_array_of_union_requires_parentheses
        type = Dry::Types["array"].of(Dry::Types["string"] | Dry::Types["integer"])
        assert_equal "(string | number)[]", @compiler.call(type)
      end

      def test_union_of_arrays_no_parentheses
        type = Dry::Types["array"].of(Dry::Types["string"]) | Dry::Types["array"].of(Dry::Types["integer"])
        assert_equal "string[] | number[]", @compiler.call(type)
      end

      def test_optional_optional_dedupes_null
        type = Dry::Types["string"].optional.optional
        assert_equal "string | null", @compiler.call(type)
      end

      def test_constrained_array_of_strings
        type = Dry::Types["array"].of(Dry::Types["string"]).constrained(min_size: 1)
        assert_equal "string[]", @compiler.call(type)
      end

      def test_custom_primitive_map
        custom_map = Dry::TypeScript::TypeCompiler::PRIMITIVE_MAP.merge(Date => "Date")
        compiler = Dry::TypeScript::TypeCompiler.new(primitive_map: custom_map)
        type = Dry::Types["date"]
        assert_equal "Date", compiler.call(type)
      end

      def test_strict_mode_raises_on_unknown
        compiler = Dry::TypeScript::TypeCompiler.new(strict: true)
        error = assert_raises(Dry::TypeScript::UnsupportedTypeError) do
          # Manually create an unknown AST node type
          compiler.send(:visit, [:unknown_type, []])
        end
        assert_match(/Unsupported AST node/, error.message)
      end

      def test_non_strict_mode_returns_unknown_for_unknown_node
        type = Dry::Types["symbol"]
        assert_equal "string", @compiler.call(type)
      end
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module Dry
  module TypeScript
    class TypeCompilerTest < Minitest::Test
      def setup
        @compiler = TypeCompiler.new
      end

      def test_compiles_string_type_to_string
        type = Dry::Types["string"]

        result = @compiler.call(type)

        assert_equal "string", result
      end

      def test_compiles_integer_type_to_number
        type = Dry::Types["integer"]

        result = @compiler.call(type)

        assert_equal "number", result
      end

      def test_compiles_float_type_to_number
        type = Dry::Types["float"]

        result = @compiler.call(type)

        assert_equal "number", result
      end

      def test_compiles_bool_type_to_boolean
        type = Dry::Types["bool"]

        result = @compiler.call(type)

        assert_equal "boolean", result
      end

      def test_compiles_nil_type_to_null
        type = Dry::Types["nil"]

        result = @compiler.call(type)

        assert_equal "null", result
      end

      def test_compiles_date_type_to_string
        type = Dry::Types["date"]

        result = @compiler.call(type)

        assert_equal "string", result
      end

      def test_compiles_time_type_to_string
        type = Dry::Types["time"]

        result = @compiler.call(type)

        assert_equal "string", result
      end

      def test_compiles_date_time_type_to_string
        type = Dry::Types["date_time"]

        result = @compiler.call(type)

        assert_equal "string", result
      end

      def test_compiles_optional_string_to_union_with_null
        type = Dry::Types["string"].optional

        result = @compiler.call(type)

        assert_equal "string | null", result
      end

      def test_compiles_optional_integer_to_union_with_null
        type = Dry::Types["integer"].optional

        result = @compiler.call(type)

        assert_equal "number | null", result
      end

      def test_compiles_array_of_strings
        type = Dry::Types["array"].of(Dry::Types["string"])

        result = @compiler.call(type)

        assert_equal "string[]", result
      end

      def test_compiles_array_of_integers
        type = Dry::Types["array"].of(Dry::Types["integer"])

        result = @compiler.call(type)

        assert_equal "number[]", result
      end

      def test_compiles_optional_array_of_integers
        type = Dry::Types["array"].of(Dry::Types["integer"]).optional

        result = @compiler.call(type)

        assert_equal "number[] | null", result
      end

      def test_compiles_union_of_string_or_integer
        type = Dry::Types["string"] | Dry::Types["integer"]

        result = @compiler.call(type)

        assert_equal "string | number", result
      end

      def test_compiles_union_of_multiple_types
        type = Dry::Types["string"] | Dry::Types["integer"] | Dry::Types["bool"]

        result = @compiler.call(type)

        assert_equal "string | number | boolean", result
      end

      def test_unwraps_constrained_integer
        type = Dry::Types["integer"].constrained(gt: 0)

        result = @compiler.call(type)

        assert_equal "number", result
      end

      def test_unwraps_constrained_string
        type = Dry::Types["string"].constrained(min_size: 1)

        result = @compiler.call(type)

        assert_equal "string", result
      end

      def test_unwraps_constrained_optional
        type = Dry::Types["string"].constrained(min_size: 1).optional

        result = @compiler.call(type)

        assert_equal "string | null", result
      end

      def test_wraps_array_of_union_in_parentheses
        type = Dry::Types["array"].of(Dry::Types["string"] | Dry::Types["integer"])

        result = @compiler.call(type)

        assert_equal "(string | number)[]", result
      end

      def test_does_not_wrap_union_of_arrays_in_parentheses
        type = Dry::Types["array"].of(Dry::Types["string"]) | Dry::Types["array"].of(Dry::Types["integer"])

        result = @compiler.call(type)

        assert_equal "string[] | number[]", result
      end

      def test_deduplicates_null_in_double_optional
        type = Dry::Types["string"].optional.optional

        result = @compiler.call(type)

        assert_equal "string | null", result
      end

      def test_unwraps_constrained_array
        type = Dry::Types["array"].of(Dry::Types["string"]).constrained(min_size: 1)

        result = @compiler.call(type)

        assert_equal "string[]", result
      end

      def test_uses_custom_primitive_map
        custom_map = Dry::TypeScript::TypeCompiler::PRIMITIVE_MAP.merge(Date => "Date")
        compiler = Dry::TypeScript::TypeCompiler.new(primitive_map: custom_map)
        type = Dry::Types["date"]

        result = compiler.call(type)

        assert_equal "Date", result
      end

      def test_strict_mode_raises_on_unknown_node
        compiler = Dry::TypeScript::TypeCompiler.new(strict: true)

        error = assert_raises(Dry::TypeScript::UnsupportedTypeError) do
          compiler.send(:visit, [:unknown_type, []])
        end

        assert_match(/Unsupported AST node/, error.message)
      end

      def test_compiles_symbol_type_to_string
        type = Dry::Types["symbol"]

        result = @compiler.call(type)

        assert_equal "string", result
      end

      def test_compile_ast_provides_public_api_for_ast_nodes
        ast = Dry::Types["string"].to_ast

        result = @compiler.compile_ast(ast)

        assert_equal "string", result
      end

      def test_compile_ast_handles_complex_union_ast
        type = Dry::Types["string"] | Dry::Types["integer"]
        ast = type.to_ast

        result = @compiler.compile_ast(ast)

        assert_equal "string | number", result
      end
    end
  end
end

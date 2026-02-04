# frozen_string_literal: true

require "test_helper"

module Dry
  module TypeScript
    class AstVisitorHelpersTest < Minitest::Test
      class TestVisitor
        include AstVisitorHelpers
        public :normalize_union, :flatten_union, :wrap_array_member, :needs_parens_in_array?
      end

      def setup
        @visitor = TestVisitor.new
      end

      def test_normalize_union_joins_types_with_pipe
        result = @visitor.normalize_union(%w[string number])

        assert_equal "string | number", result
      end

      def test_normalize_union_moves_null_to_end
        result = @visitor.normalize_union(%w[null string])

        assert_equal "string | null", result
      end

      def test_normalize_union_deduplicates_types
        result = @visitor.normalize_union(%w[string string number])

        assert_equal "string | number", result
      end

      def test_normalize_union_returns_single_type_without_pipe
        result = @visitor.normalize_union(["string"])

        assert_equal "string", result
      end

      def test_normalize_union_flattens_nested_unions
        result = @visitor.normalize_union(["string | number", "boolean"])

        assert_equal "string | number | boolean", result
      end

      def test_flatten_union_splits_on_pipe
        result = @visitor.flatten_union("string | number")

        assert_equal %w[string number], result
      end

      def test_flatten_union_preserves_parenthesized_unions
        result = @visitor.flatten_union("(string | number)")

        assert_equal ["(string | number)"], result
      end

      def test_flatten_union_returns_array_for_simple_type
        result = @visitor.flatten_union("string")

        assert_equal ["string"], result
      end

      def test_wrap_array_member_appends_brackets
        result = @visitor.wrap_array_member("string")

        assert_equal "string[]", result
      end

      def test_wrap_array_member_wraps_unions_in_parens
        result = @visitor.wrap_array_member("string | number")

        assert_equal "(string | number)[]", result
      end

      def test_wrap_array_member_wraps_intersections_in_parens
        result = @visitor.wrap_array_member("Foo & Bar")

        assert_equal "(Foo & Bar)[]", result
      end

      def test_needs_parens_in_array_returns_true_for_union
        assert @visitor.needs_parens_in_array?("string | number")
      end

      def test_needs_parens_in_array_returns_true_for_intersection
        assert @visitor.needs_parens_in_array?("Foo & Bar")
      end

      def test_needs_parens_in_array_returns_false_for_simple_type
        refute @visitor.needs_parens_in_array?("string")
      end
    end
  end
end

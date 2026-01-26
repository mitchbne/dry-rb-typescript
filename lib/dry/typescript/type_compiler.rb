# frozen_string_literal: true

module Dry
  module TypeScript
    class UnsupportedTypeError < Error; end

    class TypeCompiler
      PRIMITIVE_MAP = {
        String => "string",
        Integer => "number",
        Float => "number",
        BigDecimal => "number",
        TrueClass => "boolean",
        FalseClass => "boolean",
        NilClass => "null",
        Date => "string",
        Time => "string",
        DateTime => "string",
        Symbol => "string"
      }.freeze

      def initialize(primitive_map: PRIMITIVE_MAP, strict: false)
        @primitive_map = primitive_map
        @strict = strict
      end

      def call(type)
        visit(type.to_ast)
      end

      private

      def visit(node)
        type, body = node
        method = :"visit_#{type}"
        if respond_to?(method, true)
          send(method, body)
        else
          visit_unknown(type, body)
        end
      end

      def visit_unknown(type, body)
        raise UnsupportedTypeError, "Unsupported AST node: #{type} #{body.inspect}" if @strict

        "unknown"
      end

      def visit_nominal(node)
        primitive, _options, _meta = node
        @primitive_map.fetch(primitive, "unknown")
      end

      def visit_sum(node)
        *types, _meta = node
        ts_types = types.flat_map { |type| flatten_union(visit(type)) }.uniq

        # Normalize: put null at the end for cleaner output
        if ts_types.include?("null")
          ts_types.delete("null")
          ts_types << "null"
        end

        # If only one type remains after deduplication, return it directly
        return ts_types.first if ts_types.size == 1

        ts_types.join(" | ")
      end

      def flatten_union(ts_type)
        # Split on " | " but not when inside parentheses
        return [ts_type] unless ts_type.include?(" | ") && !ts_type.start_with?("(")

        ts_type.split(" | ")
      end

      def visit_array(node)
        member_type, _meta = node
        member_ts = visit(member_type)
        member_ts = "(#{member_ts})" if needs_parens_in_array?(member_ts)
        "#{member_ts}[]"
      end

      def needs_parens_in_array?(member_ts)
        member_ts.include?(" | ") || member_ts.include?(" & ")
      end

      def visit_constrained(node)
        base_type, _rule = node
        visit(base_type)
      end

      def visit_hash(_node)
        "Record<string, unknown>"
      end

      def visit_any(_node)
        "unknown"
      end
    end
  end
end

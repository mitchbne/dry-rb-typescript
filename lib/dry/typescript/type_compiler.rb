# frozen_string_literal: true

require_relative "ast_visitor_helpers"

module Dry
  module TypeScript
    class UnsupportedTypeError < Error; end

    class TypeCompiler
      include AstVisitorHelpers

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

      def initialize(primitive_map: nil, strict: false)
        @primitive_map = primitive_map || Dry::TypeScript.config.type_mappings
        @strict = strict
      end

      def call(type)
        compile_ast(type.to_ast)
      end

      def compile_ast(ast)
        visit(ast)
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
        normalize_union(types.map { |type| visit(type) })
      end

      def visit_array(node)
        member_type, _meta = node
        wrap_array_member(visit(member_type))
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

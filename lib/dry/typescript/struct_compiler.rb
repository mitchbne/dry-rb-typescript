# frozen_string_literal: true

require_relative "ast_visitor_helpers"
require_relative "type_naming"

module Dry
  module TypeScript
    class StructCompiler
      include AstVisitorHelpers
      include TypeNaming

      def initialize(struct_class, type_name: nil, export_style: nil, type_compiler: nil)
        @struct_class = struct_class
        @config = build_effective_config(struct_class)
        @type_name = type_name || per_struct_type_name || transform_type_name(base_type_name(struct_class))
        @export_style = export_style || @config.export_style
        @type_compiler = type_compiler || TypeCompiler.new
      end

      def per_struct_type_name
        return nil unless @struct_class.respond_to?(:_typescript_config) && @struct_class._typescript_config

        @struct_class._typescript_config.type_name
      end

      def transform_type_name(name)
        if @config.type_name_transformer
          @config.type_name_transformer.call(name)
        else
          name.split("::").last
        end
      end

      def base_type_name(struct_class)
        struct_class.name
      end

      def build_effective_config(struct_class)
        base = Dry::TypeScript.config.dup
        return base unless struct_class.respond_to?(:_typescript_config) && struct_class._typescript_config

        per_struct = struct_class._typescript_config.to_h
        base.merge(per_struct)
      end

      def call
        @dependencies = []
        @inline_stack = [@struct_class]

        members = compile_members
        typescript = build_typescript(members)

        { typescript: typescript, dependencies: @dependencies.uniq }
      end

      private

      def compile_members
        @struct_class.schema.map do |key|
          compile_member(key)
        end
      end

      def compile_member(key)
        ts_type = compile_type(key.type)
        is_nullable_type = nullable_type?(key.type)
        optional_marker = compute_optional_marker(key, is_nullable_type)
        final_type = compute_final_type(ts_type, is_nullable_type)

        "#{format_property_name(key.name)}#{optional_marker}: #{final_type};"
      end

      def nullable_type?(type)
        if type.is_a?(Dry::Types::Sum)
          left_nil = type.left.respond_to?(:primitive) && type.left.primitive == NilClass
          right_nil = type.right.respond_to?(:primitive) && type.right.primitive == NilClass
          return true if left_nil || right_nil
        end
        return nullable_type?(type.type) if type.respond_to?(:type)

        false
      end

      def compute_optional_marker(key, is_nullable_type)
        return "?" unless key.required?

        case @config.null_strategy
        when :optional, :nullable_and_optional
          is_nullable_type ? "?" : ""
        else
          ""
        end
      end

      def compute_final_type(ts_type, is_nullable_type)
        case @config.null_strategy
        when :optional
          is_nullable_type ? strip_null(ts_type) : ts_type
        else
          ts_type
        end
      end

      def strip_null(ts_type)
        ts_type.gsub(/ \| null$/, "").gsub(/^null \| /, "")
      end

      def format_property_name(name)
        name_str = transform_property_name(name.to_s)
        return name_str if valid_ts_identifier?(name_str)

        "\"#{name_str}\""
      end

      def transform_property_name(name)
        return name unless @config.property_name_transformer

        @config.property_name_transformer.call(name)
      end

      def valid_ts_identifier?(name)
        return false if name.empty?
        return false if ts_reserved_word?(name)

        name.match?(/\A[a-zA-Z_$][a-zA-Z0-9_$]*\z/)
      end

      TS_RESERVED_WORDS = %w[
        break case catch class const continue debugger default delete do else
        enum export extends false finally for function if import in instanceof
        new null return super switch this throw true try typeof var void while with
        as implements interface let package private protected public static yield
      ].freeze

      def ts_reserved_word?(name)
        TS_RESERVED_WORDS.include?(name)
      end

      def compile_type(type)
        if struct_class?(type)
          handle_struct_type(type)
        elsif sum_with_struct?(type)
          compile_sum_with_struct(type)
        elsif type.respond_to?(:to_ast)
          compile_with_struct_awareness(type)
        else
          "unknown"
        end
      end

      def sum_with_struct?(type)
        type.is_a?(Dry::Types::Sum) && contains_struct?(type)
      end

      def contains_struct?(type)
        return struct_class?(type) if !type.is_a?(Dry::Types::Sum)

        contains_struct?(type.left) || contains_struct?(type.right)
      end

      def compile_sum_with_struct(type)
        ts_types = collect_sum_types(type).map { |t| compile_type(t) }
        normalize_union(ts_types)
      end

      def collect_sum_types(type)
        return [type] unless type.is_a?(Dry::Types::Sum)

        collect_sum_types(type.left) + collect_sum_types(type.right)
      end

      def compile_with_struct_awareness(type)
        visit(type.to_ast)
      end

      def visit(node)
        type, body = node
        method = :"visit_#{type}"
        if respond_to?(method, true)
          send(method, body)
        else
          @type_compiler.compile_ast(node)
        end
      end

      def visit_nominal(node)
        primitive, _options, _meta = node
        if primitive.is_a?(Class) && primitive <= Dry::Struct
          handle_struct_type(primitive)
        else
          @type_compiler.compile_ast([:nominal, node])
        end
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

      def visit_struct(node)
        struct_class, _meta = node
        handle_struct_type(struct_class)
      end

      def handle_struct_type(struct_class)
        if struct_class == @struct_class
          @type_name
        elsif @inline_stack.include?(struct_class)
          @dependencies << struct_class unless struct_class == @struct_class
          extract_type_name(struct_class)
        elsif inline_struct?(struct_class)
          compile_inline_struct(struct_class)
        else
          @dependencies << struct_class
          extract_type_name(struct_class)
        end
      end

      def struct_class?(type)
        type.is_a?(Class) && type <= Dry::Struct
      end

      def inline_struct?(struct_class)
        parent_name = @struct_class.name
        struct_name = struct_class.name
        struct_name&.start_with?("#{parent_name}::")
      end

      def compile_inline_struct(struct_class)
        @inline_stack.push(struct_class)
        members = struct_class.schema.map do |key|
          ts_type = compile_type(key.type)
          optional_marker = key.required? ? "" : "?"
          "#{format_property_name(key.name)}#{optional_marker}: #{ts_type}"
        end
        @inline_stack.pop
        "{ #{members.join("; ")} }"
      end

      def build_typescript(members)
        members_str = members.map { |m| "  #{m}" }.join("\n")
        type_definition = "type #{@type_name} = {\n#{members_str}\n}"

        case @export_style
        when :default
          "#{type_definition}\nexport default #{@type_name}"
        else
          "export #{type_definition}"
        end
      end
    end
  end
end

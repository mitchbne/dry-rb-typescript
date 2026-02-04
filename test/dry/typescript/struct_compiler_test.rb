# frozen_string_literal: true

require "test_helper"

module Dry
  module TypeScript
    class StructCompilerTest < Minitest::Test
      module Types
        include Dry.Types
      end

      class SimpleUser < Dry::Struct
        attribute :name, Types::String
        attribute :age, Types::Integer
      end

      class UserWithOptional < Dry::Struct
        attribute :name, Types::String
        attribute :nickname, Types::String.optional
      end

      class UserWithArray < Dry::Struct
        attribute :name, Types::String
        attribute :tags, Types::Array.of(Types::String)
      end

      class UserWithNestedInline < Dry::Struct
        attribute :name, Types::String
        attribute :address do
          attribute :city, Types::String
          attribute :zip, Types::String
        end
      end

      class Address < Dry::Struct
        attribute :city, Types::String
        attribute :zip, Types::String
      end

      class UserWithReference < Dry::Struct
        attribute :name, Types::String
        attribute :address, Address
      end

      class UserWithOptionalReference < Dry::Struct
        attribute :name, Types::String
        attribute :address, Address.optional
      end

      class UserWithArrayOfStructs < Dry::Struct
        attribute :name, Types::String
        attribute :addresses, Types::Array.of(Address)
      end

      class UserWithOptionalAttribute < Dry::Struct
        attribute :name, Types::String
        attribute? :nickname, Types::String
      end

      class UserWithNestedOptionalKey < Dry::Struct
        attribute :name, Types::String
        attribute :address do
          attribute :city, Types::String
          attribute? :line2, Types::String
        end
      end

      class UserWithHyphenatedKey < Dry::Struct
        attribute :"first-name", Types::String
        attribute :age, Types::Integer
      end

      class UserWithReservedWord < Dry::Struct
        attribute :class, Types::String
        attribute :default, Types::String
      end

      class SelfReferentialNode < Dry::Struct
        attribute :value, Types::String
        attribute :next, SelfReferentialNode.optional
      end

      def test_compiles_simple_struct
        compiler = StructCompiler.new(SimpleUser)

        result = compiler.call

        expected = <<~TS.strip
          export type SimpleUser = {
            name: string;
            age: number;
          }
        TS
        assert_equal expected, result[:typescript]
        assert_empty result[:dependencies]
      end

      def test_compiles_optional_attribute_type_with_null_union
        compiler = StructCompiler.new(UserWithOptional)

        result = compiler.call

        expected = <<~TS.strip
          export type UserWithOptional = {
            name: string;
            nickname: string | null;
          }
        TS
        assert_equal expected, result[:typescript]
      end

      def test_compiles_array_attribute
        compiler = StructCompiler.new(UserWithArray)

        result = compiler.call

        expected = <<~TS.strip
          export type UserWithArray = {
            name: string;
            tags: string[];
          }
        TS
        assert_equal expected, result[:typescript]
      end

      def test_compiles_nested_inline_struct
        compiler = StructCompiler.new(UserWithNestedInline)

        result = compiler.call

        expected = <<~TS.strip
          export type UserWithNestedInline = {
            name: string;
            address: { city: string; zip: string };
          }
        TS
        assert_equal expected, result[:typescript]
      end

      def test_compiles_referenced_struct_and_tracks_dependency
        compiler = StructCompiler.new(UserWithReference)

        result = compiler.call

        expected = <<~TS.strip
          export type UserWithReference = {
            name: string;
            address: Address;
          }
        TS
        assert_equal expected, result[:typescript]
        assert_includes result[:dependencies], Address
      end

      def test_compiles_optional_referenced_struct_with_null_union
        compiler = StructCompiler.new(UserWithOptionalReference)

        result = compiler.call

        expected = <<~TS.strip
          export type UserWithOptionalReference = {
            name: string;
            address: Address | null;
          }
        TS
        assert_equal expected, result[:typescript]
        assert_includes result[:dependencies], Address
      end

      def test_compiles_array_of_structs
        compiler = StructCompiler.new(UserWithArrayOfStructs)

        result = compiler.call

        expected = <<~TS.strip
          export type UserWithArrayOfStructs = {
            name: string;
            addresses: Address[];
          }
        TS
        assert_equal expected, result[:typescript]
        assert_includes result[:dependencies], Address
      end

      def test_compiles_optional_key_with_question_mark
        compiler = StructCompiler.new(UserWithOptionalAttribute)

        result = compiler.call

        expected = <<~TS.strip
          export type UserWithOptionalAttribute = {
            name: string;
            nickname?: string;
          }
        TS
        assert_equal expected, result[:typescript]
      end

      def test_uses_custom_type_name
        compiler = StructCompiler.new(SimpleUser, type_name: "UserDTO")

        result = compiler.call

        assert_match(/^export type UserDTO = \{/, result[:typescript])
      end

      def test_default_export_style_outputs_export_default
        compiler = StructCompiler.new(SimpleUser, export_style: :default)

        result = compiler.call

        assert_includes result[:typescript], "export default SimpleUser"
      end

      def test_compiles_nested_inline_struct_with_optional_key
        compiler = StructCompiler.new(UserWithNestedOptionalKey)

        result = compiler.call

        expected = <<~TS.strip
          export type UserWithNestedOptionalKey = {
            name: string;
            address: { city: string; line2?: string };
          }
        TS
        assert_equal expected, result[:typescript]
      end

      def test_quotes_hyphenated_property_name
        compiler = StructCompiler.new(UserWithHyphenatedKey)

        result = compiler.call

        assert_includes result[:typescript], '"first-name": string;'
      end

      def test_quotes_reserved_word_property_names
        compiler = StructCompiler.new(UserWithReservedWord)

        result = compiler.call

        assert_includes result[:typescript], '"class": string;'
        assert_includes result[:typescript], '"default": string;'
      end

      def test_handles_self_referential_struct
        compiler = StructCompiler.new(SelfReferentialNode)

        result = compiler.call

        expected = <<~TS.strip
          export type SelfReferentialNode = {
            value: string;
            next: SelfReferentialNode | null;
          }
        TS
        assert_equal expected, result[:typescript]
        refute_includes result[:dependencies], SelfReferentialNode
      end

      def test_can_be_called_multiple_times
        compiler = StructCompiler.new(UserWithReference)

        result1 = compiler.call
        result2 = compiler.call

        assert_equal result1[:dependencies], result2[:dependencies]
        assert_equal 1, result2[:dependencies].count
      end

      def test_wraps_array_of_union_types_in_parentheses
        array_type = Types::Array.of(Types::String | Types::Integer)
        struct = Class.new(Dry::Struct) do
          attribute :items, array_type
        end
        compiler = StructCompiler.new(struct, type_name: "ItemsContainer")

        result = compiler.call

        assert_includes result[:typescript], "items: (string | number)[];"
      end
    end
  end
end

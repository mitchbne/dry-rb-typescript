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

      def test_simple_struct
        compiler = StructCompiler.new(SimpleUser)
        result = compiler.call

        expected = <<~TS.strip
          type SimpleUser = {
            name: string;
            age: number;
          }
        TS

        assert_equal expected, result[:typescript]
        assert_empty result[:dependencies]
      end

      def test_optional_attribute_type
        compiler = StructCompiler.new(UserWithOptional)
        result = compiler.call

        expected = <<~TS.strip
          type UserWithOptional = {
            name: string;
            nickname: string | null;
          }
        TS

        assert_equal expected, result[:typescript]
      end

      def test_array_attribute
        compiler = StructCompiler.new(UserWithArray)
        result = compiler.call

        expected = <<~TS.strip
          type UserWithArray = {
            name: string;
            tags: string[];
          }
        TS

        assert_equal expected, result[:typescript]
      end

      def test_nested_inline_struct
        compiler = StructCompiler.new(UserWithNestedInline)
        result = compiler.call

        expected = <<~TS.strip
          type UserWithNestedInline = {
            name: string;
            address: { city: string; zip: string };
          }
        TS

        assert_equal expected, result[:typescript]
      end

      def test_referenced_struct
        compiler = StructCompiler.new(UserWithReference)
        result = compiler.call

        expected = <<~TS.strip
          type UserWithReference = {
            name: string;
            address: Address;
          }
        TS

        assert_equal expected, result[:typescript]
        assert_includes result[:dependencies], Address
      end

      def test_optional_referenced_struct
        compiler = StructCompiler.new(UserWithOptionalReference)
        result = compiler.call

        expected = <<~TS.strip
          type UserWithOptionalReference = {
            name: string;
            address: Address | null;
          }
        TS

        assert_equal expected, result[:typescript]
        assert_includes result[:dependencies], Address
      end

      def test_array_of_structs
        compiler = StructCompiler.new(UserWithArrayOfStructs)
        result = compiler.call

        expected = <<~TS.strip
          type UserWithArrayOfStructs = {
            name: string;
            addresses: Address[];
          }
        TS

        assert_equal expected, result[:typescript]
        assert_includes result[:dependencies], Address
      end

      def test_optional_key_with_required_type
        compiler = StructCompiler.new(UserWithOptionalAttribute)
        result = compiler.call

        expected = <<~TS.strip
          type UserWithOptionalAttribute = {
            name: string;
            nickname?: string;
          }
        TS

        assert_equal expected, result[:typescript]
      end

      def test_custom_type_name
        compiler = StructCompiler.new(SimpleUser, type_name: "UserDTO")
        result = compiler.call

        assert_match(/^type UserDTO = \{/, result[:typescript])
      end

      def test_export_keyword
        compiler = StructCompiler.new(SimpleUser, export: true)
        result = compiler.call

        assert_match(/^export type SimpleUser = \{/, result[:typescript])
      end

      class UserWithNestedOptionalKey < Dry::Struct
        attribute :name, Types::String
        attribute :address do
          attribute :city, Types::String
          attribute? :line2, Types::String
        end
      end

      def test_nested_inline_struct_with_optional_key
        compiler = StructCompiler.new(UserWithNestedOptionalKey)
        result = compiler.call

        expected = <<~TS.strip
          type UserWithNestedOptionalKey = {
            name: string;
            address: { city: string; line2?: string };
          }
        TS

        assert_equal expected, result[:typescript]
      end

      class UserWithHyphenatedKey < Dry::Struct
        attribute :"first-name", Types::String
        attribute :age, Types::Integer
      end

      def test_hyphenated_property_name_is_quoted
        compiler = StructCompiler.new(UserWithHyphenatedKey)
        result = compiler.call

        assert_includes result[:typescript], '"first-name": string;'
      end

      class UserWithReservedWord < Dry::Struct
        attribute :class, Types::String
        attribute :default, Types::String
      end

      def test_reserved_word_property_name_is_quoted
        compiler = StructCompiler.new(UserWithReservedWord)
        result = compiler.call

        assert_includes result[:typescript], '"class": string;'
        assert_includes result[:typescript], '"default": string;'
      end

      class SelfReferentialNode < Dry::Struct
        attribute :value, Types::String
        attribute :next, SelfReferentialNode.optional
      end

      def test_self_referential_struct
        compiler = StructCompiler.new(SelfReferentialNode)
        result = compiler.call

        expected = <<~TS.strip
          type SelfReferentialNode = {
            value: string;
            next: SelfReferentialNode | null;
          }
        TS

        assert_equal expected, result[:typescript]
        refute_includes result[:dependencies], SelfReferentialNode
      end

      def test_compiler_can_be_called_multiple_times
        compiler = StructCompiler.new(UserWithReference)

        result1 = compiler.call
        result2 = compiler.call

        assert_equal result1[:dependencies], result2[:dependencies]
        assert_equal 1, result2[:dependencies].count
      end

      def test_array_of_union_types
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

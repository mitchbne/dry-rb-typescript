# frozen_string_literal: true

require "test_helper"

module Dry
  module TypeScript
    class StructMethodsTest < Minitest::Test
      module Types
        include Dry.Types
      end

      class BasicUser < Dry::Struct
        extend Dry::TypeScript::StructMethods

        attribute :name, Types::String
        attribute :age, Types::Integer
      end

      class Address < Dry::Struct
        extend Dry::TypeScript::StructMethods

        attribute :city, Types::String
        attribute :zip, Types::String
      end

      class UserWithAddress < Dry::Struct
        extend Dry::TypeScript::StructMethods

        attribute :name, Types::String
        attribute :address, Address
      end

      def test_basic_to_typescript
        result = BasicUser.to_typescript

        expected = <<~TS.strip
          type BasicUser = {
            name: string;
            age: number;
          }
        TS

        assert_equal expected, result[:typescript]
        assert_empty result[:dependencies]
      end

      def test_to_typescript_with_custom_name
        result = BasicUser.to_typescript(name: "UserDTO")

        assert_match(/^type UserDTO = \{/, result[:typescript])
      end

      def test_to_typescript_with_export
        result = BasicUser.to_typescript(export: true)

        assert_match(/^export type BasicUser = \{/, result[:typescript])
      end

      def test_to_typescript_with_both_options
        result = BasicUser.to_typescript(name: "UserDTO", export: true)

        assert_match(/^export type UserDTO = \{/, result[:typescript])
      end

      def test_to_typescript_tracks_dependencies
        result = UserWithAddress.to_typescript

        assert_includes result[:dependencies], Address
      end

      def test_multiple_structs_with_dependencies
        results = [UserWithAddress, Address].map(&:to_typescript)

        user_result = results[0]
        address_result = results[1]

        assert_includes user_result[:typescript], "address: Address;"
        assert_includes address_result[:typescript], "city: string;"
        assert_includes user_result[:dependencies], Address
        assert_empty address_result[:dependencies]
      end

      def test_to_typescript_returns_hash_with_typescript_and_dependencies
        result = BasicUser.to_typescript

        assert_kind_of Hash, result
        assert result.key?(:typescript)
        assert result.key?(:dependencies)
        assert_kind_of String, result[:typescript]
        assert_kind_of Array, result[:dependencies]
      end
    end
  end
end

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

      def test_generates_basic_typescript
        result = BasicUser.to_typescript

        expected = <<~TS.strip
          export type BasicUser = {
            name: string;
            age: number;
          }
        TS
        assert_equal expected, result[:typescript]
        assert_empty result[:dependencies]
      end

      def test_accepts_custom_name_option
        result = BasicUser.to_typescript(name: "UserDTO")

        assert_match(/^export type UserDTO = \{/, result[:typescript])
      end

      def test_accepts_default_export_style_option
        result = BasicUser.to_typescript(export_style: :default)

        assert_includes result[:typescript], "export default BasicUser"
      end

      def test_accepts_both_name_and_export_style_options
        result = BasicUser.to_typescript(name: "UserDTO", export_style: :default)

        assert_includes result[:typescript], "export default UserDTO"
      end

      def test_tracks_dependencies
        result = UserWithAddress.to_typescript

        assert_includes result[:dependencies], Address
      end

      def test_generates_correct_output_for_multiple_structs
        user_result = UserWithAddress.to_typescript
        address_result = Address.to_typescript

        assert_includes user_result[:typescript], "address: Address;"
        assert_includes address_result[:typescript], "city: string;"
        assert_includes user_result[:dependencies], Address
        assert_empty address_result[:dependencies]
      end

      def test_returns_hash_with_typescript_and_dependencies_keys
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

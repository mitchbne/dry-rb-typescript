# frozen_string_literal: true

require "test_helper"
require "dry/typescript/struct_extension"

module Dry
  module TypeScript
    class StructExtensionTest < Minitest::Test
      module Types
        include Dry.Types
      end

      class AutoExtendedUser < Dry::Struct
        attribute :name, Types::String
        attribute :email, Types::String
      end

      def test_struct_extension_adds_to_typescript_to_dry_struct
        assert_respond_to Dry::Struct, :to_typescript
      end

      def test_struct_subclass_inherits_to_typescript
        assert_respond_to AutoExtendedUser, :to_typescript
      end

      def test_auto_extended_struct_generates_typescript
        result = AutoExtendedUser.to_typescript

        expected = <<~TS.strip
          type AutoExtendedUser = {
            name: string;
            email: string;
          }
        TS

        assert_equal expected, result[:typescript]
      end
    end
  end
end

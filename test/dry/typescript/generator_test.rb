# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

module Dry
  module TypeScript
    class GeneratorTest < Minitest::Test
      module Types
        include Dry.Types
      end

      def setup
        @tmpdir = Dir.mktmpdir("dry_typescript_test")
        @structs_dir = File.join(@tmpdir, "structs")
        FileUtils.mkdir_p(@structs_dir)
        @original_config = Dry::TypeScript.config.dup
      end

      def teardown
        FileUtils.rm_rf(@tmpdir)
        Dry::TypeScript.instance_variable_set(:@config, @original_config)
        GeneratorTest.send(:remove_const, :TestAddress) if defined?(GeneratorTest::TestAddress)
        GeneratorTest.send(:remove_const, :TestUser) if defined?(GeneratorTest::TestUser)
        GeneratorTest.send(:remove_const, :TestOrder) if defined?(GeneratorTest::TestOrder)
        GeneratorTest.send(:remove_const, :TestLineItem) if defined?(GeneratorTest::TestLineItem)
      end

      def test_initializes_with_structs_array
        generator = Generator.new(structs: [])

        assert_equal [], generator.structs
      end

      def test_sorted_structs_returns_empty_for_no_structs
        generator = Generator.new(structs: [])

        result = generator.sorted_structs

        assert_equal [], result
      end

      def test_sorted_structs_returns_single_struct
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        GeneratorTest.const_set(:TestAddress, address_class)
        generator = Generator.new(structs: [TestAddress])

        result = generator.sorted_structs

        assert_equal [TestAddress], result
      end

      def test_sorted_structs_sorts_dependencies_first
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        GeneratorTest.const_set(:TestAddress, address_class)
        user_class = Class.new(Dry::Struct) do
          attribute :name, Types::String
          attribute :address, GeneratorTest::TestAddress
        end
        GeneratorTest.const_set(:TestUser, user_class)
        generator = Generator.new(structs: [TestUser, TestAddress])

        sorted = generator.sorted_structs

        address_idx = sorted.index(TestAddress)
        user_idx = sorted.index(TestUser)
        assert address_idx < user_idx, "Address should come before User"
      end

      def test_sorted_structs_handles_chain_dependencies
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        GeneratorTest.const_set(:TestAddress, address_class)
        user_class = Class.new(Dry::Struct) do
          attribute :name, Types::String
          attribute :address, GeneratorTest::TestAddress
        end
        GeneratorTest.const_set(:TestUser, user_class)
        order_class = Class.new(Dry::Struct) do
          attribute :id, Types::Integer
          attribute :user, GeneratorTest::TestUser
        end
        GeneratorTest.const_set(:TestOrder, order_class)
        generator = Generator.new(structs: [TestOrder, TestUser, TestAddress])

        sorted = generator.sorted_structs

        address_idx = sorted.index(TestAddress)
        user_idx = sorted.index(TestUser)
        order_idx = sorted.index(TestOrder)
        assert address_idx < user_idx, "Address should come before User"
        assert user_idx < order_idx, "User should come before Order"
      end

      def test_sorted_structs_handles_missing_dependencies
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        GeneratorTest.const_set(:TestAddress, address_class)
        user_class = Class.new(Dry::Struct) do
          attribute :name, Types::String
          attribute :address, GeneratorTest::TestAddress
        end
        GeneratorTest.const_set(:TestUser, user_class)
        generator = Generator.new(structs: [TestUser])

        sorted = generator.sorted_structs

        assert_equal [TestUser], sorted
      end

      def test_call_generates_all_structs
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        GeneratorTest.const_set(:TestAddress, address_class)
        user_class = Class.new(Dry::Struct) do
          attribute :name, Types::String
        end
        GeneratorTest.const_set(:TestUser, user_class)
        output_dir = File.join(@tmpdir, "types")
        Dry::TypeScript.configure do |config|
          config.output_dir = output_dir
        end
        generator = Generator.new(structs: [TestAddress, TestUser])

        result = generator.call

        assert_kind_of Hash, result
        assert_includes result.keys, TestAddress
        assert_includes result.keys, TestUser
      end

      def test_call_returns_typescript_and_dependencies
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        GeneratorTest.const_set(:TestAddress, address_class)
        generator = Generator.new(structs: [TestAddress])

        result = generator.call

        assert_kind_of Hash, result[TestAddress]
        assert result[TestAddress].key?(:typescript)
        assert result[TestAddress].key?(:dependencies)
      end
    end
  end
end

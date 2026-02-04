# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

module Dry
  module TypeScript
    class WriterTest < Minitest::Test
      module Types
        include Dry.Types
      end

      def setup
        @tmpdir = Dir.mktmpdir("dry_typescript_writer_test")
        @output_dir = File.join(@tmpdir, "types")
        @original_config = Dry::TypeScript.config.dup
        Dry::TypeScript.configure do |config|
          config.output_dir = @output_dir
        end
      end

      def teardown
        FileUtils.rm_rf(@tmpdir)
        Dry::TypeScript.instance_variable_set(:@config, @original_config)
        WriterTest.send(:remove_const, :TestAddress) if defined?(WriterTest::TestAddress)
        WriterTest.send(:remove_const, :TestUser) if defined?(WriterTest::TestUser)
        WriterTest.send(:remove_const, :TestOrder) if defined?(WriterTest::TestOrder)
      end

      def test_initializes_with_output_dir
        writer = Writer.new(output_dir: @output_dir)

        assert_equal @output_dir, writer.output_dir
      end

      def test_uses_config_output_dir_by_default
        writer = Writer.new

        assert_equal @output_dir, writer.output_dir
      end

      def test_write_creates_single_file
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        writer = Writer.new(output_dir: @output_dir)

        result = writer.write(TestAddress)

        assert File.exist?(result)
        assert_match(/TestAddress\.ts$/, result)
        content = File.read(result)
        assert_includes content, "type TestAddress"
        assert_includes content, "city: string"
      end

      def test_write_creates_output_directory
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        new_output = File.join(@tmpdir, "new", "nested", "types")
        writer = Writer.new(output_dir: new_output)

        result = writer.write(TestAddress)

        assert File.directory?(new_output)
        assert File.exist?(result)
      end

      def test_write_generates_import_for_dependency
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        user_class = Class.new(Dry::Struct) do
          attribute :name, Types::String
          attribute :address, WriterTest::TestAddress
        end
        WriterTest.const_set(:TestUser, user_class)
        writer = Writer.new(output_dir: @output_dir)
        writer.write(TestAddress)

        result = writer.write(TestUser)

        content = File.read(result)
        assert_includes content, "import type { TestAddress } from './TestAddress'"
        assert_includes content, "address: TestAddress"
      end

      def test_write_includes_fingerprint_comment
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        writer = Writer.new(output_dir: @output_dir)

        result = writer.write(TestAddress)

        content = File.read(result)
        assert_match(/^\/\/ dry-typescript fingerprint: [a-f0-9]{32}$/, content.lines.first.chomp)
      end

      def test_write_skips_unchanged_file
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        writer = Writer.new(output_dir: @output_dir)
        result1 = writer.write(TestAddress)
        mtime1 = File.mtime(result1)
        sleep 0.01

        result2 = writer.write(TestAddress)

        mtime2 = File.mtime(result2)
        assert_equal mtime1, mtime2, "File should not be rewritten if unchanged"
      end

      def test_write_updates_changed_file
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        writer = Writer.new(output_dir: @output_dir)
        result1 = writer.write(TestAddress)
        original_content = File.read(result1)
        File.write(result1, "// modified content\n")
        modified_time = File.mtime(result1)
        sleep 0.01

        result2 = writer.write(TestAddress)

        new_content = File.read(result2)
        refute_equal modified_time, File.mtime(result2)
        assert_equal original_content, new_content
      end

      def test_write_index_creates_barrel_export
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        user_class = Class.new(Dry::Struct) do
          attribute :name, Types::String
        end
        WriterTest.const_set(:TestUser, user_class)
        writer = Writer.new(output_dir: @output_dir)
        writer.write(TestAddress)
        writer.write(TestUser)

        index_path = writer.write_index([TestAddress, TestUser])

        assert File.exist?(index_path)
        content = File.read(index_path)
        assert_includes content, "export type { TestAddress } from './TestAddress'"
        assert_includes content, "export type { TestUser } from './TestUser'"
      end

      def test_cleanup_removes_stale_generated_files
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        writer = Writer.new(output_dir: @output_dir)
        writer.write(TestAddress)
        stale_file = File.join(@output_dir, "OldStruct.ts")
        File.write(stale_file, "#{Writer::FINGERPRINT_PREFIX} abc123\ntype OldStruct = {}")

        writer.cleanup(current_structs: [TestAddress])

        refute File.exist?(stale_file), "Stale generated file should be removed"
        assert File.exist?(File.join(@output_dir, "TestAddress.ts")), "Current file should remain"
      end

      def test_cleanup_preserves_index_file
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        writer = Writer.new(output_dir: @output_dir)
        writer.write(TestAddress)
        writer.write_index([TestAddress])

        writer.cleanup(current_structs: [TestAddress])

        assert File.exist?(File.join(@output_dir, "index.ts")), "Index file should remain"
      end

      def test_write_all_writes_multiple_structs_with_index
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        user_class = Class.new(Dry::Struct) do
          attribute :name, Types::String
          attribute :address, WriterTest::TestAddress
        end
        WriterTest.const_set(:TestUser, user_class)
        writer = Writer.new(output_dir: @output_dir)

        result = writer.write_all([TestAddress, TestUser])

        assert_includes result[:files], File.join(@output_dir, "TestAddress.ts")
        assert_includes result[:files], File.join(@output_dir, "TestUser.ts")
        assert_equal File.join(@output_dir, "index.ts"), result[:index]
      end

      def test_write_respects_export_config
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        Dry::TypeScript.configure do |config|
          config.output_dir = @output_dir
          config.export_keyword = true
        end
        writer = Writer.new(output_dir: @output_dir)

        result = writer.write(TestAddress)

        content = File.read(result)
        assert_includes content, "export type TestAddress"
      end

      def test_write_force_overwrites_file
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        writer = Writer.new(output_dir: @output_dir)
        result1 = writer.write(TestAddress)
        mtime1 = File.mtime(result1)
        sleep 0.01

        result2 = writer.write(TestAddress, force: true)

        mtime2 = File.mtime(result2)
        refute_equal mtime1, mtime2, "File should be rewritten with force: true"
      end

      def test_write_handles_multiple_dependencies
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        user_class = Class.new(Dry::Struct) do
          attribute :name, Types::String
        end
        WriterTest.const_set(:TestUser, user_class)
        order_class = Class.new(Dry::Struct) do
          attribute :id, Types::Integer
          attribute :user, WriterTest::TestUser
          attribute :shipping_address, WriterTest::TestAddress
        end
        WriterTest.const_set(:TestOrder, order_class)
        writer = Writer.new(output_dir: @output_dir)
        writer.write(TestAddress)
        writer.write(TestUser)

        result = writer.write(TestOrder)

        content = File.read(result)
        assert_includes content, "import type { TestUser } from './TestUser'"
        assert_includes content, "import type { TestAddress } from './TestAddress'"
      end

      def test_cleanup_preserves_non_generated_files
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        writer = Writer.new(output_dir: @output_dir)
        writer.write(TestAddress)
        user_file = File.join(@output_dir, "CustomHelper.ts")
        File.write(user_file, "// user-authored file\nexport const helper = () => {}")

        writer.cleanup(current_structs: [TestAddress])

        assert File.exist?(user_file), "User-authored file should remain"
        assert File.exist?(File.join(@output_dir, "TestAddress.ts"))
      end

      def test_write_all_detects_type_name_collisions
        user1 = Class.new(Dry::Struct) do
          attribute :name, Types::String

          def self.name
            "Nested1::TestUser"
          end
        end
        user2 = Class.new(Dry::Struct) do
          attribute :email, Types::String

          def self.name
            "Nested2::TestUser"
          end
        end
        writer = Writer.new(output_dir: @output_dir)

        assert_raises(Dry::TypeScript::Error) do
          writer.write_all([user1, user2])
        end
      end

      def test_imports_are_sorted_alphabetically
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        user_class = Class.new(Dry::Struct) do
          attribute :name, Types::String
        end
        WriterTest.const_set(:TestUser, user_class)
        order_class = Class.new(Dry::Struct) do
          attribute :id, Types::Integer
          attribute :user, WriterTest::TestUser
          attribute :shipping_address, WriterTest::TestAddress
        end
        WriterTest.const_set(:TestOrder, order_class)
        writer = Writer.new(output_dir: @output_dir)

        result = writer.write_all([TestOrder, TestAddress, TestUser])

        content = File.read(result[:files].find { |f| f.include?("TestOrder") })
        lines = content.lines
        address_line = lines.index { |l| l.include?("TestAddress") }
        user_line = lines.index { |l| l.include?("TestUser") }
        assert address_line < user_line, "Imports should be sorted alphabetically"
      end

      def test_index_exports_are_sorted_alphabetically
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        user_class = Class.new(Dry::Struct) do
          attribute :name, Types::String
        end
        WriterTest.const_set(:TestUser, user_class)
        writer = Writer.new(output_dir: @output_dir)

        result = writer.write_all([TestUser, TestAddress])

        content = File.read(result[:index])
        lines = content.lines
        address_line = lines.index { |l| l.include?("TestAddress") }
        user_line = lines.index { |l| l.include?("TestUser") }
        assert address_line < user_line, "Index exports should be sorted alphabetically"
      end

      def test_write_all_filters_imports_to_generated_set
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        WriterTest.const_set(:TestAddress, address_class)
        user_class = Class.new(Dry::Struct) do
          attribute :name, Types::String
          attribute :address, WriterTest::TestAddress
        end
        WriterTest.const_set(:TestUser, user_class)
        writer = Writer.new(output_dir: @output_dir)

        result = writer.write_all([TestUser])

        content = File.read(result[:files].first)
        refute_includes content, "import type { TestAddress }", "Should not import non-generated struct"
      end
    end
  end
end

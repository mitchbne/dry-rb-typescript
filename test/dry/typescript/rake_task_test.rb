# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "rake"

module Dry
  module TypeScript
    module RakeTaskTestHelper
      module Types
        include Dry.Types
      end

      private

      def setup_rake_task(barrel_file:)
        @tmpdir = Dir.mktmpdir("dry_typescript_rake_test")
        @output_dir = File.join(@tmpdir, "types")
        @original_config = Dry::TypeScript.config.dup
        Rake::Task.clear
        Dry::TypeScript.configure do |config|
          config.barrel_file = barrel_file
        end
      end

      def teardown_rake_task
        FileUtils.rm_rf(@tmpdir)
        Dry::TypeScript.instance_variable_set(:@config, @original_config)
        RakeTaskTestHelper.send(:remove_const, :RakeAddress) if defined?(RakeTaskTestHelper::RakeAddress)
        RakeTaskTestHelper.send(:remove_const, :RakeUser) if defined?(RakeTaskTestHelper::RakeUser)
      end
    end

    class RakeTaskWithoutBarrelFileTest < Minitest::Test
      include RakeTaskTestHelper

      def setup
        setup_rake_task(barrel_file: false)
      end

      def teardown
        teardown_rake_task
      end

      def test_defines_generate_task
        RakeTask.new(:typescript) do |t|
          t.output_dir = @output_dir
          t.structs = []
        end

        assert Rake::Task.task_defined?("typescript:generate")
      end

      def test_defines_clean_task
        RakeTask.new(:typescript) do |t|
          t.output_dir = @output_dir
          t.structs = []
        end

        assert Rake::Task.task_defined?("typescript:clean")
      end

      def test_generate_task_creates_files_without_index
        address_class = Class.new(Dry::Struct) do
          attribute :city, RakeTaskTestHelper::Types::String
        end
        RakeTaskTestHelper.const_set(:RakeAddress, address_class)
        RakeTask.new(:typescript) do |t|
          t.output_dir = @output_dir
          t.structs = [RakeTaskTestHelper::RakeAddress]
        end

        Rake::Task["typescript:generate"].invoke

        assert File.exist?(File.join(@output_dir, "RakeAddress.ts"))
        refute File.exist?(File.join(@output_dir, "index.ts"))
      end

      def test_clean_task_removes_output_dir
        address_class = Class.new(Dry::Struct) do
          attribute :city, RakeTaskTestHelper::Types::String
        end
        RakeTaskTestHelper.const_set(:RakeAddress, address_class)
        RakeTask.new(:typescript) do |t|
          t.output_dir = @output_dir
          t.structs = [RakeTaskTestHelper::RakeAddress]
        end
        Rake::Task["typescript:generate"].invoke

        Rake::Task["typescript:clean"].invoke

        refute File.directory?(@output_dir)
      end

      def test_accepts_custom_name
        RakeTask.new(:ts) do |t|
          t.output_dir = @output_dir
          t.structs = []
        end

        assert Rake::Task.task_defined?("ts:generate")
        assert Rake::Task.task_defined?("ts:clean")
      end

      def test_generate_sorts_structs_by_dependency
        address_class = Class.new(Dry::Struct) do
          attribute :city, RakeTaskTestHelper::Types::String
        end
        RakeTaskTestHelper.const_set(:RakeAddress, address_class)
        user_class = Class.new(Dry::Struct) do
          attribute :name, RakeTaskTestHelper::Types::String
          attribute :address, RakeTaskTestHelper::RakeAddress
        end
        RakeTaskTestHelper.const_set(:RakeUser, user_class)
        RakeTask.new(:typescript) do |t|
          t.output_dir = @output_dir
          t.structs = [RakeTaskTestHelper::RakeUser, RakeTaskTestHelper::RakeAddress]
        end

        Rake::Task["typescript:generate"].invoke

        user_content = File.read(File.join(@output_dir, "RakeUser.ts"))
        assert_includes user_content, "import type { RakeAddress }"
      end

      def test_generate_cleans_stale_generated_files
        address_class = Class.new(Dry::Struct) do
          attribute :city, RakeTaskTestHelper::Types::String
        end
        RakeTaskTestHelper.const_set(:RakeAddress, address_class)
        FileUtils.mkdir_p(@output_dir)
        stale_file = File.join(@output_dir, "OldStruct.ts")
        File.write(stale_file, "#{Writer::FINGERPRINT_PREFIX} abc123\ntype OldStruct = {}")
        RakeTask.new(:typescript) do |t|
          t.output_dir = @output_dir
          t.structs = [RakeTaskTestHelper::RakeAddress]
        end

        Rake::Task["typescript:generate"].invoke

        refute File.exist?(stale_file)
        assert File.exist?(File.join(@output_dir, "RakeAddress.ts"))
      end
    end

    class RakeTaskWithBarrelFileTest < Minitest::Test
      include RakeTaskTestHelper

      def setup
        setup_rake_task(barrel_file: true)
      end

      def teardown
        teardown_rake_task
      end

      def test_defines_generate_task
        RakeTask.new(:typescript) do |t|
          t.output_dir = @output_dir
          t.structs = []
        end

        assert Rake::Task.task_defined?("typescript:generate")
      end

      def test_defines_clean_task
        RakeTask.new(:typescript) do |t|
          t.output_dir = @output_dir
          t.structs = []
        end

        assert Rake::Task.task_defined?("typescript:clean")
      end

      def test_generate_task_creates_files_with_index
        address_class = Class.new(Dry::Struct) do
          attribute :city, RakeTaskTestHelper::Types::String
        end
        RakeTaskTestHelper.const_set(:RakeAddress, address_class)
        RakeTask.new(:typescript) do |t|
          t.output_dir = @output_dir
          t.structs = [RakeTaskTestHelper::RakeAddress]
        end

        Rake::Task["typescript:generate"].invoke

        assert File.exist?(File.join(@output_dir, "RakeAddress.ts"))
        assert File.exist?(File.join(@output_dir, "index.ts"))
      end

      def test_clean_task_removes_output_dir
        address_class = Class.new(Dry::Struct) do
          attribute :city, RakeTaskTestHelper::Types::String
        end
        RakeTaskTestHelper.const_set(:RakeAddress, address_class)
        RakeTask.new(:typescript) do |t|
          t.output_dir = @output_dir
          t.structs = [RakeTaskTestHelper::RakeAddress]
        end
        Rake::Task["typescript:generate"].invoke

        Rake::Task["typescript:clean"].invoke

        refute File.directory?(@output_dir)
      end

      def test_accepts_custom_name
        RakeTask.new(:ts) do |t|
          t.output_dir = @output_dir
          t.structs = []
        end

        assert Rake::Task.task_defined?("ts:generate")
        assert Rake::Task.task_defined?("ts:clean")
      end

      def test_generate_sorts_structs_by_dependency
        address_class = Class.new(Dry::Struct) do
          attribute :city, RakeTaskTestHelper::Types::String
        end
        RakeTaskTestHelper.const_set(:RakeAddress, address_class)
        user_class = Class.new(Dry::Struct) do
          attribute :name, RakeTaskTestHelper::Types::String
          attribute :address, RakeTaskTestHelper::RakeAddress
        end
        RakeTaskTestHelper.const_set(:RakeUser, user_class)
        RakeTask.new(:typescript) do |t|
          t.output_dir = @output_dir
          t.structs = [RakeTaskTestHelper::RakeUser, RakeTaskTestHelper::RakeAddress]
        end

        Rake::Task["typescript:generate"].invoke

        user_content = File.read(File.join(@output_dir, "RakeUser.ts"))
        assert_includes user_content, "import type { RakeAddress }"
      end

      def test_generate_cleans_stale_generated_files
        address_class = Class.new(Dry::Struct) do
          attribute :city, RakeTaskTestHelper::Types::String
        end
        RakeTaskTestHelper.const_set(:RakeAddress, address_class)
        FileUtils.mkdir_p(@output_dir)
        stale_file = File.join(@output_dir, "OldStruct.ts")
        File.write(stale_file, "#{Writer::FINGERPRINT_PREFIX} abc123\ntype OldStruct = {}")
        RakeTask.new(:typescript) do |t|
          t.output_dir = @output_dir
          t.structs = [RakeTaskTestHelper::RakeAddress]
        end

        Rake::Task["typescript:generate"].invoke

        refute File.exist?(stale_file)
        assert File.exist?(File.join(@output_dir, "RakeAddress.ts"))
      end
    end
  end
end

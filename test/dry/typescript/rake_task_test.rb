# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "rake"

module Dry
  module TypeScript
    class RakeTaskTest < Minitest::Test
      module Types
        include Dry.Types
      end

      def setup
        @tmpdir = Dir.mktmpdir("dry_typescript_rake_test")
        @output_dir = File.join(@tmpdir, "types")
        @original_config = Dry::TypeScript.config.dup
        Rake::Task.clear
      end

      def teardown
        FileUtils.rm_rf(@tmpdir)
        Dry::TypeScript.instance_variable_set(:@config, @original_config)
        RakeTaskTest.send(:remove_const, :RakeAddress) if defined?(RakeTaskTest::RakeAddress)
        RakeTaskTest.send(:remove_const, :RakeUser) if defined?(RakeTaskTest::RakeUser)
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

      def test_generate_task_creates_files
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        RakeTaskTest.const_set(:RakeAddress, address_class)
        RakeTask.new(:typescript) do |t|
          t.output_dir = @output_dir
          t.structs = [RakeAddress]
        end

        Rake::Task["typescript:generate"].invoke

        assert File.exist?(File.join(@output_dir, "RakeAddress.ts"))
        assert File.exist?(File.join(@output_dir, "index.ts"))
      end

      def test_clean_task_removes_output_dir
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        RakeTaskTest.const_set(:RakeAddress, address_class)
        RakeTask.new(:typescript) do |t|
          t.output_dir = @output_dir
          t.structs = [RakeAddress]
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
          attribute :city, Types::String
        end
        RakeTaskTest.const_set(:RakeAddress, address_class)
        user_class = Class.new(Dry::Struct) do
          attribute :name, Types::String
          attribute :address, RakeTaskTest::RakeAddress
        end
        RakeTaskTest.const_set(:RakeUser, user_class)
        RakeTask.new(:typescript) do |t|
          t.output_dir = @output_dir
          t.structs = [RakeUser, RakeAddress]
        end

        Rake::Task["typescript:generate"].invoke

        user_content = File.read(File.join(@output_dir, "RakeUser.ts"))
        assert_includes user_content, "import type { RakeAddress }"
      end

      def test_generate_cleans_stale_generated_files
        address_class = Class.new(Dry::Struct) do
          attribute :city, Types::String
        end
        RakeTaskTest.const_set(:RakeAddress, address_class)
        FileUtils.mkdir_p(@output_dir)
        stale_file = File.join(@output_dir, "OldStruct.ts")
        File.write(stale_file, "#{Writer::FINGERPRINT_PREFIX} abc123\ntype OldStruct = {}")
        RakeTask.new(:typescript) do |t|
          t.output_dir = @output_dir
          t.structs = [RakeAddress]
        end

        Rake::Task["typescript:generate"].invoke

        refute File.exist?(stale_file)
        assert File.exist?(File.join(@output_dir, "RakeAddress.ts"))
      end
    end
  end
end

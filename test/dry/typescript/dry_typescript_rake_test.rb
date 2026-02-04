# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

module Dry
  module TypeScript
    class FreshnessCheckerRakeIntegrationTest < Minitest::Test
      def setup
        @tmpdir = Dir.mktmpdir("dry_typescript_check_test")
        @output_dir = File.join(@tmpdir, "types")
        @original_config = Dry::TypeScript.config.dup
        Dry::TypeScript.configure do |config|
          config.output_dir = @output_dir
        end
      end

      def teardown
        FileUtils.rm_rf(@tmpdir)
        Dry::TypeScript.instance_variable_set(:@config, @original_config)
      end

      def test_check_task_uses_freshness_checker
        types = Dry.Types
        person = Class.new(Dry::Struct) do
          define_method(:self_name) { "RakeTestPerson" }
          define_singleton_method(:name) { "RakeTestPerson" }
          attribute :name, types::String
        end

        writer = Writer.new(output_dir: @output_dir)
        writer.write_all([person])

        checker = FreshnessChecker.new(output_dir: @output_dir, structs: [person])
        result = checker.call

        assert result.fresh?
      end

      def test_check_detects_stale_files
        types = Dry.Types
        person = Class.new(Dry::Struct) do
          define_singleton_method(:name) { "RakeTestPerson" }
          attribute :name, types::String
        end

        writer = Writer.new(output_dir: @output_dir)
        writer.write_all([person])

        File.write(File.join(@output_dir, "RakeTestPerson.ts"), "// modified")

        checker = FreshnessChecker.new(output_dir: @output_dir, structs: [person])
        result = checker.call

        refute result.fresh?
        assert_includes result.errors, "Out of date: RakeTestPerson.ts"
      end
    end
  end
end

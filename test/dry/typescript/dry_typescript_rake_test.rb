# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

module Dry
  module TypeScript
    module FreshnessCheckerRakeIntegrationTestHelper
      private

      def setup_freshness_checker_rake(barrel_file:)
        @tmpdir = Dir.mktmpdir("dry_typescript_check_test")
        @output_dir = File.join(@tmpdir, "types")
        @original_config = Dry::TypeScript.config.dup
        @types = Dry.Types
        Dry::TypeScript.configure do |config|
          config.output_dir = @output_dir
          config.barrel_file = barrel_file
        end
      end

      def teardown_freshness_checker_rake
        FileUtils.rm_rf(@tmpdir)
        Dry::TypeScript.instance_variable_set(:@config, @original_config)
      end

      def make_person
        types = @types
        Class.new(Dry::Struct) do
          define_singleton_method(:name) { "RakeTestPerson" }
          attribute :name, types::String
        end
      end
    end

    class FreshnessCheckerRakeIntegrationWithoutBarrelFileTest < Minitest::Test
      include FreshnessCheckerRakeIntegrationTestHelper

      def setup
        setup_freshness_checker_rake(barrel_file: false)
      end

      def teardown
        teardown_freshness_checker_rake
      end

      def test_check_task_uses_freshness_checker
        person = make_person

        writer = Writer.new(output_dir: @output_dir)
        writer.write_all([person])

        checker = FreshnessChecker.new(output_dir: @output_dir, structs: [person])
        result = checker.call

        assert result.fresh?
      end

      def test_check_detects_stale_files
        person = make_person

        writer = Writer.new(output_dir: @output_dir)
        writer.write_all([person])

        File.write(File.join(@output_dir, "RakeTestPerson.ts"), "// modified")

        checker = FreshnessChecker.new(output_dir: @output_dir, structs: [person])
        result = checker.call

        refute result.fresh?
        assert_includes result.errors, "Out of date: RakeTestPerson.ts"
      end
    end

    class FreshnessCheckerRakeIntegrationWithBarrelFileTest < Minitest::Test
      include FreshnessCheckerRakeIntegrationTestHelper

      def setup
        setup_freshness_checker_rake(barrel_file: true)
      end

      def teardown
        teardown_freshness_checker_rake
      end

      def test_check_task_uses_freshness_checker
        person = make_person

        writer = Writer.new(output_dir: @output_dir)
        writer.write_all([person])

        checker = FreshnessChecker.new(output_dir: @output_dir, structs: [person])
        result = checker.call

        assert result.fresh?
      end

      def test_check_detects_stale_files
        person = make_person

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

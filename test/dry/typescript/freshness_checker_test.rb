# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

module Dry
  module TypeScript
    class FreshnessCheckerTest < Minitest::Test
      def setup
        @tmpdir = Dir.mktmpdir("dry_typescript_freshness_test")
        @output_dir = File.join(@tmpdir, "types")
        @original_config = Dry::TypeScript.config.dup
        @types = Dry.Types
        Dry::TypeScript.configure do |config|
          config.output_dir = @output_dir
        end
      end

      def teardown
        FileUtils.rm_rf(@tmpdir)
        Dry::TypeScript.instance_variable_set(:@config, @original_config)
      end

      def test_returns_fresh_when_no_structs_and_no_files
        checker = FreshnessChecker.new(output_dir: @output_dir, structs: [])

        result = checker.call

        assert result.fresh?
        assert_empty result.errors
      end

      def test_returns_not_fresh_when_files_missing
        person = make_struct("FreshPerson", name: @types::String)

        checker = FreshnessChecker.new(output_dir: @output_dir, structs: [person])
        result = checker.call

        refute result.fresh?
        assert_includes result.errors, "Missing: FreshPerson.ts"
        assert_includes result.errors, "Missing: index.ts"
      end

      def test_returns_fresh_when_files_match
        person = make_struct("FreshPerson", name: @types::String)

        Writer.new(output_dir: @output_dir).write_all([person])

        checker = FreshnessChecker.new(output_dir: @output_dir, structs: [person])
        result = checker.call

        assert result.fresh?
        assert_empty result.errors
      end

      def test_returns_not_fresh_when_file_content_differs
        person = make_struct("FreshPerson", name: @types::String)

        Writer.new(output_dir: @output_dir).write_all([person])
        File.write(File.join(@output_dir, "FreshPerson.ts"), "// modified")

        checker = FreshnessChecker.new(output_dir: @output_dir, structs: [person])
        result = checker.call

        refute result.fresh?
        assert_includes result.errors, "Out of date: FreshPerson.ts"
      end

      def test_returns_not_fresh_when_extra_generated_file_exists
        person = make_struct("FreshPerson", name: @types::String)

        Writer.new(output_dir: @output_dir).write_all([person])
        File.write(
          File.join(@output_dir, "OldStruct.ts"),
          "#{Writer::FINGERPRINT_PREFIX} abc123\ntype OldStruct = {}"
        )

        checker = FreshnessChecker.new(output_dir: @output_dir, structs: [person])
        result = checker.call

        refute result.fresh?
        assert_includes result.errors, "Extra: OldStruct.ts"
      end

      def test_ignores_non_generated_extra_files
        person = make_struct("FreshPerson", name: @types::String)

        Writer.new(output_dir: @output_dir).write_all([person])
        File.write(File.join(@output_dir, "CustomHelper.ts"), "// user file")

        checker = FreshnessChecker.new(output_dir: @output_dir, structs: [person])
        result = checker.call

        assert result.fresh?
      end

      def test_checks_index_file_freshness
        person = make_struct("FreshPerson", name: @types::String)

        Writer.new(output_dir: @output_dir).write_all([person])
        File.write(File.join(@output_dir, "index.ts"), "// modified")

        checker = FreshnessChecker.new(output_dir: @output_dir, structs: [person])
        result = checker.call

        refute result.fresh?
        assert_includes result.errors, "Out of date: index.ts"
      end

      def test_handles_structs_with_dependencies
        address = make_struct("FreshAddress", city: @types::String)
        person = make_struct("FreshPerson", name: @types::String, address: address)

        Writer.new(output_dir: @output_dir).write_all([address, person])

        checker = FreshnessChecker.new(output_dir: @output_dir, structs: [address, person])
        result = checker.call

        assert result.fresh?
      end

      private

      def make_struct(name, **attributes)
        klass = Class.new(Dry::Struct) do
          define_singleton_method(:name) { name }
        end
        attributes.each { |attr_name, type| klass.attribute(attr_name, type) }
        klass
      end
    end
  end
end

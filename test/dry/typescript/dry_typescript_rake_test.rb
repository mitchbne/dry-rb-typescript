# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "rake"

module DryTypescriptRakeTestStructs
  Types = Dry.Types

  class DryNamespaceExclusionTestStruct < Dry::Struct
    attribute :name, Types::String
  end
end

module Dry
  module TypeScript
    class DryTypescriptRakeTest < Minitest::Test
      def setup
        @tmpdir = Dir.mktmpdir("dry_typescript_rake_test")
        @output_dir = File.join(@tmpdir, "types")
        @original_output_dir = Dry::TypeScript.config.output_dir
        @original_dirs = Dry::TypeScript.dirs.dup
        Rake::Task.clear
        Rake.application = Rake::Application.new
        Rake::Task.define_task(:environment)
        load File.expand_path("../../../lib/dry/typescript/tasks/dry_typescript.rake", __dir__)
      end

      def teardown
        FileUtils.rm_rf(@tmpdir)
        Dry::TypeScript.config.output_dir = @original_output_dir
        Dry::TypeScript.dirs = @original_dirs
      end

      def test_generate_excludes_dry_namespace_classes
        Dry::TypeScript.config.output_dir = @output_dir

        Rake::Task["dry_typescript:generate"].invoke

        refute File.exist?(File.join(@output_dir, "Value.ts")),
          "Should not generate Value.ts for Dry::Struct::Value"
        assert File.exist?(File.join(@output_dir, "DryNamespaceExclusionTestStruct.ts")),
          "Should generate TypeScript file for user-defined struct"
      end
    end
  end
end

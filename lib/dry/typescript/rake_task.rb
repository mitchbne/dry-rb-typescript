# frozen_string_literal: true

require "rake"
require "rake/tasklib"

module Dry
  module TypeScript
    class RakeTask < Rake::TaskLib
      attr_accessor :name, :output_dir, :structs

      def initialize(name = :typescript)
        super()
        @name = name
        @output_dir = nil
        @structs = []

        yield self if block_given?

        define_tasks
      end

      private

      def define_tasks
        namespace @name do
          desc "Generate TypeScript type definitions"
          task :generate do
            require "dry-typescript"

            dir = @output_dir || Dry::TypeScript.config.output_dir
            generator = Generator.new(structs: @structs)
            sorted = generator.sorted_structs

            writer = Writer.new(output_dir: dir)
            writer.write_all(sorted)
            writer.cleanup(current_structs: sorted)

            puts "Generated #{sorted.size} TypeScript files in #{dir}"
          end

          desc "Remove generated TypeScript files"
          task :clean do
            require "fileutils"

            dir = @output_dir || Dry::TypeScript.config.output_dir
            if dir && File.directory?(dir)
              FileUtils.rm_rf(dir)
              puts "Removed #{dir}"
            end
          end
        end
      end
    end
  end
end

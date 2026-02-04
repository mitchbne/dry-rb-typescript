# frozen_string_literal: true

require "fileutils"

module Dry
  module TypeScript
    class FreshnessChecker
      include FileContentBuilder

      Result = ::Struct.new(:fresh?, :errors, keyword_init: true)

      def initialize(output_dir:, structs:)
        @output_dir = output_dir
        @structs = structs
      end

      def call
        return Result.new(fresh?: true, errors: []) if @structs.empty? && current_files.empty?

        errors = []
        generated_content = generate_to_memory

        all_files = (current_files + generated_content.keys).uniq

        all_files.each do |relative_path|
          current_path = File.join(@output_dir, relative_path)
          current_exists = File.exist?(current_path)
          generated_exists = generated_content.key?(relative_path)

          if !current_exists && generated_exists
            errors << "Missing: #{relative_path}"
          elsif current_exists && !generated_exists
            errors << "Extra: #{relative_path}" if generated_file?(current_path)
          elsif current_exists && generated_exists
            current_content = normalize_content(File.read(current_path))
            expected_content = normalize_content(generated_content[relative_path])

            if current_content != expected_content
              errors << "Out of date: #{relative_path}"
            end
          end
        end

        Result.new(fresh?: errors.empty?, errors: errors)
      end

      private

      def generate_to_memory
        content = {}
        generator = Generator.new(structs: @structs)
        sorted = generator.sorted_structs

        sorted.each do |struct_class|
          compiler = StructCompiler.new(struct_class)
          result = compiler.call
          filename = extract_type_name(struct_class) + ".ts"
          content[filename] = build_file_content(result, filter_imports_to: sorted)
        end

        content["index.ts"] = build_index_content(sorted)
        content
      end

      def current_files
        return [] unless Dir.exist?(@output_dir)

        Dir.glob(File.join(@output_dir, "*.ts")).map { |f| File.basename(f) }
      end

      def generated_file?(filepath)
        return false unless File.exist?(filepath)

        first_line = File.open(filepath, &:readline).chomp
        first_line.start_with?(FINGERPRINT_PREFIX)
      rescue EOFError
        false
      end

      def normalize_content(content)
        lines = content.lines
        if lines.first&.start_with?(FINGERPRINT_PREFIX)
          remaining = lines.drop(1)
          remaining = remaining.drop(1) if remaining.first == "\n"
          remaining.join
        else
          content
        end
      end
    end
  end
end

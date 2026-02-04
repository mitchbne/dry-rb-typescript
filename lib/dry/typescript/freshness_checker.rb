# frozen_string_literal: true

require "fileutils"

module Dry
  module TypeScript
    class FreshnessChecker
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
          content[filename] = build_file_content(result, sorted)
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
        first_line.start_with?(Writer::FINGERPRINT_PREFIX)
      rescue EOFError
        false
      end

      def normalize_content(content)
        lines = content.lines
        if lines.first&.start_with?(Writer::FINGERPRINT_PREFIX)
          lines.drop(1).join
        else
          content
        end
      end

      def extract_type_name(struct_class)
        if struct_class.respond_to?(:_typescript_config) && struct_class._typescript_config&.type_name
          return struct_class._typescript_config.type_name
        end

        name = struct_class.name.split("::").last

        if Dry::TypeScript.config.type_name_transformer
          name = Dry::TypeScript.config.type_name_transformer.call(name)
        end

        name
      end

      def build_file_content(result, all_structs)
        imports = build_imports(result[:dependencies], all_structs)
        typescript = result[:typescript]

        if imports.empty?
          "#{typescript}\n"
        else
          "#{imports}\n\n#{typescript}\n"
        end
      end

      def build_imports(dependencies, all_structs)
        filtered = dependencies.uniq.select { |d| all_structs.include?(d) }
        sorted = filtered.sort_by { |d| extract_type_name(d) }

        sorted.map do |dep_class|
          type_name = extract_type_name(dep_class)
          "import type { #{type_name} } from './#{type_name}'"
        end.join("\n")
      end

      def build_index_content(structs)
        sorted = structs.sort_by { |s| extract_type_name(s) }
        exports = sorted.map do |struct_class|
          type_name = extract_type_name(struct_class)
          "export type { #{type_name} } from './#{type_name}'"
        end

        exports.join("\n") + "\n"
      end
    end
  end
end

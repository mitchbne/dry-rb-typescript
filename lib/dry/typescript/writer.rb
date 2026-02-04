# frozen_string_literal: true

require "digest"
require "fileutils"

module Dry
  module TypeScript
    class Writer
      include ExportHelpers

      FINGERPRINT_PREFIX = "// dry-typescript fingerprint:"

      attr_reader :output_dir

      def initialize(output_dir: nil)
        @output_dir = output_dir || Dry::TypeScript.config.output_dir
        @generated_set = nil
      end

      def write(struct_class, force: false)
        ensure_output_dir

        compiler = StructCompiler.new(struct_class)
        result = compiler.call

        filename = "#{extract_type_name(struct_class)}.ts"
        filepath = File.join(@output_dir, filename)

        content = build_file_content(result, struct_class)
        fingerprint = compute_fingerprint(content)
        full_content = "#{FINGERPRINT_PREFIX} #{fingerprint}\n#{content}"

        return filepath if !force && file_matches_fingerprint?(filepath, fingerprint)

        atomic_write(filepath, full_content)
        filepath
      end

      def write_all(struct_classes)
        ensure_output_dir
        detect_collisions!(struct_classes)

        @generated_set = struct_classes.to_set

        files = struct_classes.map { |s| write(s) }
        index = write_index(struct_classes)

        @generated_set = nil

        { files: files, index: index }
      end

      def write_index(struct_classes)
        ensure_output_dir

        sorted_classes = struct_classes.sort_by { |s| extract_type_name(s) }
        exports = sorted_classes.map do |struct_class|
          type_name = extract_type_name(struct_class)
          build_index_export(type_name)
        end

        content = exports.join("\n") + "\n"
        fingerprint = compute_fingerprint(content)
        full_content = "#{FINGERPRINT_PREFIX} #{fingerprint}\n#{content}"

        filepath = File.join(@output_dir, "index.ts")

        return filepath if file_matches_fingerprint?(filepath, fingerprint)

        atomic_write(filepath, full_content)
        filepath
      end

      def cleanup(current_structs:)
        return unless File.directory?(@output_dir)

        expected_files = current_structs.map { |s| "#{extract_type_name(s)}.ts" }
        expected_files << "index.ts"

        Dir[File.join(@output_dir, "*.ts")].each do |filepath|
          next if expected_files.include?(File.basename(filepath))
          next unless generated_file?(filepath)

          File.delete(filepath)
        end
      end

      private

      def ensure_output_dir
        FileUtils.mkdir_p(@output_dir)
      end

      def extract_type_name(struct_class)
        # Use per-struct config type_name if available
        if struct_class.respond_to?(:_typescript_config) && struct_class._typescript_config&.type_name
          return struct_class._typescript_config.type_name
        end

        name = struct_class.name.split("::").last

        # Apply global type_name_transformer if configured
        if Dry::TypeScript.config.type_name_transformer
          name = Dry::TypeScript.config.type_name_transformer.call(name)
        end

        name
      end

      def detect_collisions!(struct_classes)
        names = struct_classes.map { |s| extract_type_name(s) }
        duplicates = names.group_by(&:itself).select { |_, v| v.size > 1 }.keys

        return if duplicates.empty?

        raise Error, "Type name collision detected: #{duplicates.join(", ")}. " \
                     "Multiple structs resolve to the same TypeScript filename."
      end

      def build_file_content(result, _struct_class)
        imports = build_imports(result[:dependencies])
        typescript = result[:typescript]

        if imports.empty?
          "#{typescript}\n"
        else
          "#{imports}\n\n#{typescript}\n"
        end
      end

      def build_imports(dependencies)
        filtered = filter_dependencies(dependencies)
        sorted = filtered.sort_by { |d| extract_type_name(d) }

        sorted.map do |dep_class|
          type_name = extract_type_name(dep_class)
          build_import_statement(type_name)
        end.join("\n")
      end

      def filter_dependencies(dependencies)
        deps = dependencies.uniq
        deps = deps.select { |d| @generated_set.include?(d) } if @generated_set
        deps
      end

      def compute_fingerprint(content)
        Digest::SHA256.hexdigest(content)[0, 32]
      end

      def file_matches_fingerprint?(filepath, fingerprint)
        return false unless File.exist?(filepath)

        first_line = File.open(filepath, &:readline).chomp.gsub(/\r/, "")
        first_line == "#{FINGERPRINT_PREFIX} #{fingerprint}"
      rescue EOFError
        false
      end

      def generated_file?(filepath)
        return false unless File.exist?(filepath)

        first_line = File.open(filepath, &:readline).chomp
        first_line.start_with?(FINGERPRINT_PREFIX)
      rescue EOFError
        false
      end

      def atomic_write(filepath, content)
        require "tempfile"
        dir = File.dirname(filepath)
        Tempfile.create(["dry_ts_", ".ts"], dir) do |tmp|
          tmp.write(content)
          tmp.close
          File.rename(tmp.path, filepath)
        end
      end
    end
  end
end

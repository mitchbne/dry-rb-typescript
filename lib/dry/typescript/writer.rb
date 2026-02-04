# frozen_string_literal: true

require "digest"
require "fileutils"

module Dry
  module TypeScript
    class Writer
      include FileContentBuilder

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

        source_location = extract_source_location(struct_class)
        content = build_file_content(result, filter_imports_to: @generated_set, source_location: source_location)
        fingerprint = compute_fingerprint(content)
        full_content = "#{FINGERPRINT_PREFIX} #{fingerprint}\n\n#{content}"

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

        content = build_index_content(struct_classes)
        fingerprint = compute_fingerprint(content)
        full_content = "#{FINGERPRINT_PREFIX} #{fingerprint}\n\n#{content}"

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

      def extract_source_location(struct_class)
        location = Object.const_source_location(struct_class.name)
        return nil unless location

        absolute_path = location.first
        make_relative_path(absolute_path)
      rescue NameError, TypeError
        nil
      end

      def make_relative_path(absolute_path)
        root = defined?(Rails) ? Rails.root.to_s : @output_dir
        return absolute_path unless absolute_path.start_with?(root)

        Pathname.new(absolute_path).relative_path_from(Pathname.new(root)).to_s
      end

      def detect_collisions!(struct_classes)
        names = struct_classes.map { |s| extract_type_name(s) }
        duplicates = names.group_by(&:itself).select { |_, v| v.size > 1 }.keys

        return if duplicates.empty?

        raise Error, "Type name collision detected: #{duplicates.join(", ")}. " \
                     "Multiple structs resolve to the same TypeScript filename."
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

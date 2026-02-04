# frozen_string_literal: true

module Dry
  module TypeScript
    module Listen
      class << self
        attr_accessor :started

        def call(run_on_start: true, options: {}, &block)
          return if started
          return unless Dry::TypeScript.enabled?

          watch_dirs = Dry::TypeScript.dirs.select { |path| dir_exists?(path) }.map { |path| File.expand_path(path) }
          return if watch_dirs.empty?

          @block = block

          gem "listen"
          require "listen"

          self.started = true

          relative_paths = watch_dirs.map { |path| relative_path(path) }
          debug("Watching #{relative_paths.inspect}")

          listener(watch_dirs.map(&:to_s), options).start
          regenerate if run_on_start
        end

        def stop
          return unless started

          @listener&.stop
          self.started = false
        end

        private

        def listener(paths, options)
          @listener = ::Listen.to(*paths, options) do |changed, added, removed|
            changes = compute_changes(paths, changed, added, removed)

            next unless changes.any?

            debug(changes.map { |key, value| "#{key}=#{value.inspect}" }.join(", "))

            @block&.call
            regenerate
          end
        end

        def compute_changes(paths, changed, added, removed)
          paths = paths.map { |path| relative_path(path) }

          {
            changed: included_on_watched_paths(paths, changed),
            added: included_on_watched_paths(paths, added),
            removed: included_on_watched_paths(paths, removed)
          }.select { |_k, v| v.any? }
        end

        def included_on_watched_paths(paths, changes)
          changes.map { |change| relative_path(change) }.select do |change|
            paths.any? { |path| change.start_with?(path) }
          end
        end

        def relative_path(path)
          base = defined?(Rails) && Rails.respond_to?(:root) && Rails.root ? Rails.root.to_s : Dir.pwd
          path.to_s.sub(%r{^#{Regexp.escape(base)}/?}, "")
        end

        def dir_exists?(path)
          path.respond_to?(:exist?) ? path.exist? : File.directory?(path.to_s)
        end

        def regenerate
          return unless Dry::TypeScript.enabled?

          StructDiscovery.eager_load_dirs
          structs = StructDiscovery.discover_structs
          return if structs.empty?

          generator = Generator.new(structs: structs)
          sorted = generator.sorted_structs

          writer = Writer.new
          writer.write_all(sorted)
          writer.cleanup(current_structs: sorted)

          debug("Regenerated #{sorted.size} TypeScript files")
        end

        def debug(message)
          return unless ENV["DRY_TYPESCRIPT_DEBUG"]

          puts "[dry-typescript] #{message}"
        end
      end
    end
  end
end

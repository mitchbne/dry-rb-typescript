# frozen_string_literal: true

namespace :dry_typescript do
  desc "Generate TypeScript type definitions from Dry::Struct classes"
  task generate: :environment do
    require "dry-typescript"

    Dry::TypeScript.dirs.each do |dir|
      if defined?(Rails) && Rails.autoloaders.main.respond_to?(:eager_load_dir)
        Rails.autoloaders.main.eager_load_dir(dir) if Dir.exist?(dir)
      end
    end

    structs = ObjectSpace.each_object(Class).select do |klass|
      klass < Dry::Struct && klass.name && !klass.name.empty?
    end
    structs = structs.reject { |klass| klass.name.start_with?("Dry::") }

    generator = Dry::TypeScript::Generator.new(structs: structs)
    sorted = generator.sorted_structs

    writer = Dry::TypeScript::Writer.new
    writer.write_all(sorted)
    writer.cleanup(current_structs: sorted)

    puts "Generated #{sorted.size} TypeScript files in #{Dry::TypeScript.config.output_dir}"
  end

  desc "Remove generated TypeScript files and regenerate"
  task refresh: :environment do
    require "dry-typescript"
    require "fileutils"

    dir = Dry::TypeScript.config.output_dir
    FileUtils.rm_rf(dir) if dir && File.directory?(dir)

    Rake::Task["dry_typescript:generate"].invoke
  end

  desc "Remove generated TypeScript files"
  task clean: :environment do
    require "dry-typescript"
    require "fileutils"

    dir = Dry::TypeScript.config.output_dir
    if dir && File.directory?(dir)
      FileUtils.rm_rf(dir)
      puts "Removed #{dir}"
    end
  end

  desc "Check if generated TypeScript types are up to date (for CI)"
  task check: :environment do
    require "dry-typescript"

    Dry::TypeScript.dirs.each do |dir|
      if defined?(Rails) && Rails.autoloaders.main.respond_to?(:eager_load_dir)
        Rails.autoloaders.main.eager_load_dir(dir) if Dir.exist?(dir)
      end
    end

    structs = ObjectSpace.each_object(Class).select do |klass|
      klass < Dry::Struct && klass.name && !klass.name.empty?
    end
    structs = structs.reject { |klass| klass.name.start_with?("Dry::") }

    checker = Dry::TypeScript::FreshnessChecker.new(
      output_dir: Dry::TypeScript.config.output_dir,
      structs: structs
    )
    result = checker.call

    if result.fresh?
      puts "TypeScript types are up to date."
    else
      puts "TypeScript types are out of sync:"
      result.errors.each { |e| puts "  - #{e}" }
      puts ""
      puts "Run 'bin/rails dry_typescript:generate' to update."
      exit 1
    end
  end
end

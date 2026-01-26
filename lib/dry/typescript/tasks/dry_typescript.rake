# frozen_string_literal: true

namespace :dry_typescript do
  desc "Generate TypeScript type definitions from Dry::Struct classes"
  task generate: :environment do
    require "dry-typescript"

    structs = ObjectSpace.each_object(Class).select do |klass|
      klass < Dry::Struct && klass.name && !klass.name.empty?
    end

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
end

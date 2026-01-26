# frozen_string_literal: true

require_relative "lib/dry/typescript/version"

Gem::Specification.new do |spec|
  spec.name = "dry-typescript"
  spec.version = Dry::TypeScript::VERSION
  spec.authors = ["Mitch Smith"]
  spec.email = ["mitch@example.com"]

  spec.summary = "Generate TypeScript type definitions from Dry::Struct classes"
  spec.description = "A Ruby gem that converts Dry::Struct definitions to TypeScript types using a visitor pattern"
  spec.homepage = "https://github.com/mitchbne/dry-typescript"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ examples/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "dry-types", "~> 1.7"
  spec.add_dependency "dry-struct", "~> 1.6"

  spec.add_development_dependency "listen", "~> 3.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "railties", ">= 7.0"
  spec.add_development_dependency "rake", "~> 13.0"
end

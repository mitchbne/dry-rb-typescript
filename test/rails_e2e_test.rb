# frozen_string_literal: true

require "test_helper"
require "fileutils"

class RailsE2ETest < Minitest::Test
  RAILS_APP_DIR = File.expand_path("../examples/rails_app", __dir__)
  TYPES_DIR = File.join(RAILS_APP_DIR, "app/javascript/types")
  EXPECTED_DIR = File.join(RAILS_APP_DIR, "expected")

  def setup
    cleanup_generated_files
    boot_rails_app
  end

  def teardown
    cleanup_generated_files
  end

  def test_railtie_configures_output_dir
    assert_equal Pathname.new(TYPES_DIR), Dry::TypeScript.config.output_dir
  end

  def test_railtie_configures_dirs
    expected = [Pathname.new(File.join(RAILS_APP_DIR, "app/structs"))]
    assert_equal expected, Dry::TypeScript.config.dirs
  end

  def test_structs_are_dry_structs
    assert address_class < Dry::Struct
    assert user_class < Dry::Struct
  end

  def test_generates_correct_typescript_files
    structs = [address_class, user_class]
    generator = Dry::TypeScript::Generator.new(structs: structs)
    writer = Dry::TypeScript::Writer.new(output_dir: TYPES_DIR)

    writer.write_all(generator.sorted_structs)

    assert_file_matches_expected("Address.ts")
    assert_file_matches_expected("User.ts")
    assert_file_matches_expected("index.ts")
  end

  def test_user_depends_on_address
    structs = [user_class, address_class]
    generator = Dry::TypeScript::Generator.new(structs: structs)
    sorted = generator.sorted_structs

    assert_equal [address_class, user_class], sorted, "Address should come before User"
  end

  private

  def address_class
    Object.const_get(:Address)
  end

  def user_class
    Object.const_get(:User)
  end

  def boot_rails_app
    return if @@booted ||= false

    ENV["RAILS_ENV"] = "development"
    ENV["DISABLE_DRY_TYPESCRIPT"] = "false"

    require "rails"
    require "active_support/railtie"
    require "dry-typescript"

    $LOAD_PATH.unshift File.join(RAILS_APP_DIR, "app/structs")

    require File.join(RAILS_APP_DIR, "config/application")
    Rails.application.config.root = Pathname.new(RAILS_APP_DIR)

    Rails.application.initialize! unless Rails.application.initialized?

    load File.join(RAILS_APP_DIR, "config/initializers/dry_typescript.rb")

    require File.join(RAILS_APP_DIR, "app/structs/address")
    require File.join(RAILS_APP_DIR, "app/structs/user")

    @@booted = true
  end

  def cleanup_generated_files
    Dir[File.join(TYPES_DIR, "*.ts")].each { |f| File.delete(f) }
  end

  def assert_file_matches_expected(filename)
    expected_path = File.join(EXPECTED_DIR, filename)
    actual_path = File.join(TYPES_DIR, filename)

    assert File.exist?(actual_path), "Expected #{filename} to be generated"

    expected_content = File.read(expected_path)
    actual_content = strip_fingerprint(File.read(actual_path))

    assert_equal expected_content, actual_content, "#{filename} content mismatch"
  end

  def strip_fingerprint(content)
    content.sub(%r{^// dry-typescript fingerprint: [a-f0-9]+\n}, "")
  end
end

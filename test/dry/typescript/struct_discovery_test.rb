# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class StructDiscoveryTest < Minitest::Test
  def setup
    @original_dirs = Dry::TypeScript.dirs.dup
  end

  def teardown
    Dry::TypeScript.dirs = @original_dirs
  end

  def test_discover_structs_returns_user_defined_structs
    user_struct = Class.new(Dry::Struct) do
      def self.name
        "TestUserStruct"
      end
    end

    structs = Dry::TypeScript::StructDiscovery.discover_structs

    assert_includes structs, user_struct
  end

  def test_discover_structs_excludes_dry_namespaced_classes
    structs = Dry::TypeScript::StructDiscovery.discover_structs

    dry_structs = structs.select { |s| s.name&.start_with?("Dry::") }
    assert_empty dry_structs, "Expected no Dry:: namespaced structs, got: #{dry_structs.map(&:name)}"
  end

  def test_discover_structs_excludes_anonymous_classes
    Class.new(Dry::Struct)

    structs = Dry::TypeScript::StructDiscovery.discover_structs

    anonymous = structs.select { |s| s.name.nil? || s.name.empty? }
    assert_empty anonymous
  end

  def test_eager_load_dirs_calls_rails_autoloader_for_each_dir
    Dir.mktmpdir do |dir|
      Dry::TypeScript.dirs = [dir]

      eager_load_calls = []
      mock_autoloader = Object.new
      mock_autoloader.define_singleton_method(:eager_load_dir) { |path| eager_load_calls << path }

      mock_autoloaders = Object.new
      mock_autoloaders.define_singleton_method(:main) { mock_autoloader }

      with_mock_rails(autoloaders: mock_autoloaders) do
        Dry::TypeScript::StructDiscovery.eager_load_dirs
      end

      assert_equal [File.expand_path(dir)], eager_load_calls
    end
  end

  def test_eager_load_dirs_skips_nonexistent_directories
    Dry::TypeScript.dirs = ["/nonexistent/path/12345"]

    eager_load_calls = []
    mock_autoloader = Object.new
    mock_autoloader.define_singleton_method(:eager_load_dir) { |path| eager_load_calls << path }

    mock_autoloaders = Object.new
    mock_autoloaders.define_singleton_method(:main) { mock_autoloader }

    with_mock_rails(autoloaders: mock_autoloaders) do
      Dry::TypeScript::StructDiscovery.eager_load_dirs
    end

    assert_empty eager_load_calls
  end

  def test_eager_load_dirs_does_nothing_without_rails
    original_rails = defined?(::Rails) ? ::Rails : nil

    suppress_warnings { Object.send(:remove_const, :Rails) if defined?(::Rails) }

    Dir.mktmpdir do |dir|
      Dry::TypeScript.dirs = [dir]

      Dry::TypeScript::StructDiscovery.eager_load_dirs
    end
  ensure
    suppress_warnings { Object.const_set(:Rails, original_rails) } if original_rails
  end

  private

  def with_mock_rails(autoloaders:)
    original_rails = defined?(::Rails) ? ::Rails : nil

    suppress_warnings do
      Object.const_set(:Rails, Module.new do
        define_singleton_method(:autoloaders) { autoloaders }
        define_singleton_method(:respond_to?) { |method| method == :autoloaders || super(method) }
      end)
    end

    yield
  ensure
    suppress_warnings do
      Object.send(:remove_const, :Rails)
      Object.const_set(:Rails, original_rails) if original_rails
    end
  end

  def suppress_warnings
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = original_verbosity
  end
end

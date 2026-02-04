# frozen_string_literal: true

require "test_helper"
require "dry/typescript/listen"
require "tmpdir"
require "fileutils"

class ListenTest < Minitest::Test
  def setup
    @original_dirs = Dry::TypeScript.dirs.dup
    @original_output_dir = Dry::TypeScript.config.output_dir
    Dry::TypeScript::Listen.started = false
  end

  def teardown
    Dry::TypeScript.dirs = @original_dirs
    Dry::TypeScript.config.output_dir = @original_output_dir
    Dry::TypeScript::Listen.stop
  end

  def test_does_not_start_when_disabled
    ENV["DISABLE_DRY_TYPESCRIPT"] = "true"

    Dry::TypeScript::Listen.call

    refute Dry::TypeScript::Listen.started
  ensure
    ENV.delete("DISABLE_DRY_TYPESCRIPT")
  end

  def test_does_not_start_twice
    ENV["RAILS_ENV"] = "development"
    Dir.mktmpdir do |dir|
      Dry::TypeScript.dirs = [dir]
      begin
        require "listen"

        Dry::TypeScript::Listen.call(run_on_start: false)
        first_started = Dry::TypeScript::Listen.started
        Dry::TypeScript::Listen.call(run_on_start: false)

        assert first_started
        assert_equal first_started, Dry::TypeScript::Listen.started
      rescue LoadError
        skip "listen gem not available"
      end
    end
  ensure
    ENV.delete("RAILS_ENV")
  end

  def test_does_not_start_with_empty_dirs
    ENV["RAILS_ENV"] = "development"
    Dry::TypeScript.dirs = []
    begin
      require "listen"

      Dry::TypeScript::Listen.call(run_on_start: false)

      refute Dry::TypeScript::Listen.started
    rescue LoadError
      skip "listen gem not available"
    end
  ensure
    ENV.delete("RAILS_ENV")
  end

  def test_does_not_start_with_nonexistent_dirs
    ENV["RAILS_ENV"] = "development"
    Dry::TypeScript.dirs = ["/nonexistent/path/12345"]
    begin
      require "listen"

      Dry::TypeScript::Listen.call(run_on_start: false)

      refute Dry::TypeScript::Listen.started
    rescue LoadError
      skip "listen gem not available"
    end
  ensure
    ENV.delete("RAILS_ENV")
  end
end

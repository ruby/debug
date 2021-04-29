# frozen_string_literal: true

require 'minitest'

require_relative 'utils'
require_relative '../../lib/debug/test_console'
require_relative '../../lib/debug/console'

module DEBUGGER__
  #
  # Extends Minitest's base test case and provides defaults for all tests.
  #
  class TestCase < Minitest::Test
    include TestUtils

    def self.before_suite
      DEBUGGER__::Session.ui_console = DEBUGGER__::TestUI_Console.new
    end

    #
    # Reset to default state before each test
    #
    def setup
      ui_console.clear
    end

    #
    # Cleanup temp files, and dummy classes/modules.
    #
    def teardown
      cleanup_namespace
      clear_example_file
    end

    #
    # Removes test example file and its memoization
    #
    def clear_example_file
      example_file.close

      delete_example_file

      @example_file = nil
    end

    def cleanup_namespace
      force_remove_const(DEBUGGER__, example_class)
      force_remove_const(DEBUGGER__, example_module)
      force_remove_const(DEBUGGER__, 'SESSION')
    end

    #
    # Path to file where test code is saved
    #
    def example_path
      File.join(example_folder, 'debugger_example.rb')
    end

    #
    # Temporary file where code for each test is saved
    #
    def example_file
      @example_file ||= File.new(example_path, 'w+')
    end

    #
    # Temporary folder where the test file lives
    #
    def example_folder
      @example_folder ||= File.realpath(Dir.tmpdir)
    end

    #
    # Name of the temporary test class
    #
    def example_class
      "#{camelized_path}Class"
    end

    #
    # Name of the temporary test module
    #
    def example_module
      "#{camelized_path}Module"
    end

    private

    def camelized_path
      #
      # Converts +str+ from an_underscored-or-dasherized_string to
      # ACamelizedString.
      #
      File.basename(example_path, '.rb').dup.split(/[_-]/).map(&:capitalize).join('')
    end

    def delete_example_file
      File.unlink(example_file)
    rescue StandardError
      # On windows we need the file closed before deleting it, and sometimes it
      # didn't have time to close yet. So retry until we can delete it.
      retry
    end
  end
end

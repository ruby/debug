# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class IrbTest < ConsoleTestCase
    def setup
      @original_pager = ENV["PAGER"]
      @original_home = ENV["HOME"]
      @original_xdg_config_home = ENV["XDG_CONFIG_HOME"]
      @original_irbrc = ENV["IRBRC"]

      ENV["PAGER"] = "cat"
      ENV["HOME"] = ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir
      ENV["IRBRC"] = nil
    end

    def teardown
      ENV["PAGER"] = @original_pager
      ENV["HOME"] = @original_home
      ENV["XDG_CONFIG_HOME"] = @original_xdg_config_home
      ENV["IRBRC"] = @original_irbrc
    end

    def program
      <<~RUBY
      1| a = 1
      2| b = 2
      RUBY
    end

    def test_irb_command_is_disabled_in_remote_mode
      debug_code(program, remote: :remote_only) do
        type 'irb'
        assert_line_text 'IRB is not supported on the remote console.'
        type 'q!'
      end
    end

    def test_irb_command_switches_console_to_irb
      debug_code(program, remote: false) do
        type 'irb'
        type '123'
        assert_line_text 'irb:rdbg(main):002> 123'
        type 'irb_info'
        assert_line_text('IRB version:')
        type 'next'
        type 'info'
        assert_line_text([/a = 1/, /b = nil/])
        type 'q!'
      end
    end

    def test_irb_console_config_activates_irb
      ENV["RUBY_DEBUG_IRB_CONSOLE"] = "true"

      debug_code(program, remote: false) do
        type '123'
        assert_line_text 'irb:rdbg(main):002> 123'
        type 'irb_info'
        assert_line_text('IRB version:')
        type 'next'
        type 'info'
        assert_line_text([/a = 1/, /b = nil/])
        type 'q!'
      end
    ensure
      ENV["RUBY_DEBUG_IRB_CONSOLE"] = nil
    end
  end
end

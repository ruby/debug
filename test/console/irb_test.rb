# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class IrbTest < ConsoleTestCase
    def setup
      @original_pager = ENV["PAGER"]
      ENV["PAGER"] = "cat"
    end

    def teardown
      ENV["PAGER"] = @original_pager
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
        assert_line_text 'IRB is supported on the remote console.'
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
  end
end

# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class TrapTest < ConsoleTestCase
    def program
      <<~RUBY
     1| trap('SIGINT'){ puts "SIGINT" }
     2| Process.kill('SIGINT', Process.pid)
     3| p :ok
      RUBY
    end

    def test_sigint
      debug_code program, remote: false do
        type 'b 3'
        type 'c'
        assert_line_num 2
        assert_line_text(/is registered as SIGINT handler/)
        type 'sigint'
        assert_line_num 3
        assert_line_text(/SIGINT/)
        type 'c'
      end
    end

    def test_trap_with
      debug_code %q{
        1| trap(:INT){} # Symbol
        2| _ = 1
      }, remote: false do
        type 'n'
        type 'n'
      end

      debug_code %q{
        1| trap('INT'){} # String
        2| _ = 1
      }, remote: false do
        type 'n'
        type 'n'
      end

      debug_code %q{
        1| trap(Signal.list['INT']){} if Signal.list['INT'] # Integer
        2| _ = 1
      }, remote: false do
        type 'n'
        type 'n'
      end
    end
  end
end


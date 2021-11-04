# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class TrapTest < TestCase
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
        assert_debugger_out(/is registerred as SIGINT handler/)
        type 'sigint'
        assert_line_num 3
        assert_debugger_out(/SIGINT/)
        type 'c'
      end
    end
  end
end


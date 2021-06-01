# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class MethodBreakpointTest < TestCase
    def program
      <<~RUBY
      a = 1

      a.abs
      RUBY
    end

    def test_debugger_stops_when_the_exception_raised
      debug_code(program) do
        type 'b Integer#abs'
        type 'continue'
        assert_line_num(3)
        type 'quit'
        type 'y'
      end
    end
  end
end

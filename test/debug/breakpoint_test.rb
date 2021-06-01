# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class MethodBreakpointTest < TestCase
    def program
      <<~RUBY
      1| a = 1
      2|
      3| a.abs
      RUBY
    end

    def test_debugger_stops_when_the_exception_raised
      debug_code(program) do
        type 'b Integer#abs'
        type 'continue'

        if RUBY_VERSION.to_f >= 3.0
          assert_line_text(/Integer#abs at <internal:/)
        else
          # it doesn't show any source before Ruby 3.0
          assert_line_text(/<main>/)
        end

        type 'quit'
        type 'y'
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class BasicCatchTest < TestCase
    def program
      <<~RUBY
      1| a = 1
      2| b = 2
      3|
      4| 1/0
      RUBY
    end

    def test_debugger_stops_when_the_exception_raised
      debug_code(program) do
        type 'catch ZeroDivisionError'
        type 'continue'
        assert_line_text(/Integer#\//)
        type 'quit'
        type 'y'
      end
    end

    def test_debugger_stops_when_child_exception_raised
      debug_code(program) do
        type 'catch StandardError'
        type 'continue'
        assert_line_text(/Integer#\//)
        type 'quit'
        type 'y'
      end
    end
  end

  class ReraisedExceptionCatchTest < TestCase
    def program
      <<~RUBY
      1| def foo
      2|   bar
      3| rescue ZeroDivisionError
      4|   raise
      5| end
      6|
      7| def bar
      8|   1/0
      9| end
     10|
     11| foo
      RUBY
    end

    def test_debugger_stops_when_the_exception_raised
      debug_code(program) do
        type 'catch ZeroDivisionError'
        type 'continue'
        assert_line_text(/Integer#\//)
        type 's'
        assert_line_text(/Object#bar/)
        type 'quit'
        type 'y'
      end
    end
  end
end

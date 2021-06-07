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

  class NamespacedExceptionCatchTest < TestCase
    def program
      <<~RUBY
         1| class TestException < StandardError; end
         2|
         3| module Foo
         4|   class TestException < StandardError; end
         5|
         6|   def self.raised_exception
         7|     raise TestException
         8|   end
         9| end
        10|
        11| # we need this rescue + binding.bp workaround because the test framework can't handle exception exit yet
        12| Foo.raised_exception rescue nil
        13|
        14| binding.bp
      RUBY
    end

    def test_catch_without_namespace_does_not_stop_at_exception
      debug_code(program) do
        type 'catch TestException'
        type 'continue'
        assert_line_num(14)
        type 'quit'
        type 'y'
      end
    end

    def test_catch_with_namespace_stops_at_exception
      debug_code(program) do
        type 'catch Foo::TestException'
        type 'continue'
        assert_line_num(7)
        type 'continue'
        assert_line_num(14)
        type 'quit'
        type 'y'
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class DebuggerLocalsTest < TestCase
    class RaisedTest < TestCase
      def program
        <<~RUBY
     1| _rescued_ = 1111
     2| foo rescue nil
     3|
     4| # check repl variable doesn't leak to the program
     5| result = _rescued_ * 2
     6| binding.b
        RUBY
      end

      def test_raised_is_accessible_from_repl
        debug_code(program) do
          type "catch Exception"
          type "c"
          type "_raised"
          assert_line_text(/#<NameError: undefined local variable or method `foo' for main:Object/)
          type "c"
          type "result"
          assert_line_text(/2222/)
          type "c"
        end
      end

      def test_raised_is_accessible_from_command
        debug_code(program) do
          type "catch Exception pre: p _raised"
          type "c"
          assert_line_text(/#<NameError: undefined local variable or method `foo' for main:Object/)
          type "c"
          type "result"
          assert_line_text(/2222/)
          type "c"
        end
      end
    end

    class ReturnedTest < TestCase
      def program
        <<~RUBY
   1| _return = 1111
   2|
   3| def foo
   4|   "foo"
   5| end
   6|
   7| foo
   8|
   9| # check repl variable doesn't leak to the program
  10| result = _return * 2
  11|
  12| binding.b
        RUBY
      end

      def test_returned_is_accessible_from_repl
        debug_code(program) do
          type "b 5"
          type "c"
          type "_return + 'bar'"
          assert_line_text(/"foobar"/)
          type "c"
          type "result"
          assert_line_text(/2222/)
          type "q!"
        end
      end

      def test_returned_is_accessible_from_command
        debug_code(program) do
          type "b 5 pre: p _return + 'bar'"
          type "c"
          assert_line_text(/"foobar"/)
          type "c"
          type "result"
          assert_line_text(/2222/)
          type "q!"
        end
      end
    end
  end
end

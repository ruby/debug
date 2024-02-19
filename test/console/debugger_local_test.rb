# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class DebuggerLocalsTest < ConsoleTestCase
    class REPLLocalsTest < ConsoleTestCase
      def program
        <<~RUBY
        1| a = 1
        RUBY
      end

      def test_locals_added_in_locals_are_accessible_between_evaluations
        debug_code(program) do
          type "y = 50"
          type "y"
          assert_line_text(/50/)
          type "c"
        end
      end
    end

    class RaisedTest < ConsoleTestCase
      class RubyMethodTest < ConsoleTestCase
        def program
          <<~RUBY
       1| foo rescue nil
          RUBY
        end

        def test_raised_is_accessible_from_repl
          debug_code(program) do
            type "catch Exception"
            type "c"
            type "_raised"
            assert_line_text(/undefined local variable or method [`']foo' for main/)
            type "c"
          end
        end

        def test_raised_is_accessible_from_command
          debug_code(program) do
            type "catch Exception pre: p _raised"
            type "c"
            assert_line_text(/undefined local variable or method [`']foo' for main/)
            type "c"
          end
        end
      end

      class CMethodTest < ConsoleTestCase
        def program
          <<~RUBY
       1| 1/0 rescue nil
          RUBY
        end

        def test_raised_is_accessible_from_repl
          debug_code(program) do
            type "catch Exception"
            type "c"
            type "_raised"
            assert_line_text(/ZeroDivisionError/)
            type "c"
          end
        end

        def test_raised_is_accessible_from_command
          debug_code(program) do
            type "catch Exception pre: p _raised"
            type "c"
            assert_line_text(/ZeroDivisionError/)
            type "c"
          end
        end
      end

      class EncapsulationTest < ConsoleTestCase
        def program
          <<~RUBY
         1| 1/0 rescue nil
         2| a = _raised
          RUBY
        end

        def test_raised_doesnt_leak_to_program_binding
          debug_code(program) do
            type "catch StandardError"
            type "c"
            # stops for ZeroDivisionError
            type "info"
            type "_raised"
            assert_line_text(/ZeroDivisionError/)
            type "c"

            # stops for NoMethodError because _raised is not defined in the program
            type "_raised"
            assert_line_text(/undefined local variable or method [`']_raised' for main/)
            type "c"
          end
        end
      end
    end

    class ReturnedTest < ConsoleTestCase
      def program
        <<~RUBY
   1| def foo
   2|   "foo"
   3| end
   4|
   5| foo
        RUBY
      end

      def test_returned_is_accessible_from_repl
        debug_code(program) do
          type "b 3"
          type "c"
          type "_return + 'bar'"
          assert_line_text(/"foobar"/)
          type "c"
        end
      end

      def test_returned_is_accessible_from_command
        debug_code(program) do
          type "b 3 pre: p _return + 'bar'"
          type "c"
          assert_line_text(/"foobar"/)
          type "c"
        end
      end

      class EncapsulationTest < ConsoleTestCase
        def program
          <<~RUBY
         1| def foo
         2|   "foo"
         3| end
         4|
         5| foo
         6| puts _return
          RUBY
        end

        def test_raised_doesnt_leak_to_program_binding
          debug_code(program) do
            type "catch StandardError"
            type "b 3"
            type "c"
            type "_return + 'bar'"
            assert_line_text(/"foobar"/)
            type "c"
            # stops for NoMethodError because _return is not defined in the program
            type "_raised"
            assert_line_text(/undefined local variable or method [`']_return' for main/)
            type "c"
          end
        end
      end
    end
  end
end

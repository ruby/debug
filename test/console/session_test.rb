# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class ConsoleStartTest < TestCase
    def program
      <<~RUBY
       1| a = 1
       2| b = 2
       3| require "debug"
       4| DEBUGGER__.start
       5| c = 3
       6| binding.break
       7| "foo"
      RUBY
    end

    def test_debugger_session_starts_correctly
      run_ruby(program) do
        assert_line_num(5)
        type 'c'
        assert_line_num(6)
        type 'c'
      end
    end
  end

  class RequireStartTest
    class OptionRequireTest < TestCase
      def program
        <<~RUBY
         1| a = 1
         2| b = 2
         3| binding.break
         4| "foo"
        RUBY
      end

      def test_debugger_session_starts_correctly
        run_ruby(program, options: "-r debug/start") do
          assert_line_num(1)
          type 'c'
          assert_line_num(3)
          type 'c'
        end
      end
    end

    class CodeRequireTest < TestCase
      def program
        <<~RUBY
         1| a = 1
         2| b = 2
         3| require "debug/start"
         4|
         5| c = 3
         6| binding.break
         7| "foo"
        RUBY
      end

      def test_debugger_session_starts_correctly
        run_ruby(program) do
          assert_line_num(5)
          type 'c'
          assert_line_num(6)
          type 'c'
        end
      end
    end
  end
end

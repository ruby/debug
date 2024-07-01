# frozen_string_literal: true

require 'debug/session'
require_relative '../support/console_test_case'

module DEBUGGER__
  class ConsoleStartTest < ConsoleTestCase
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
    class OptionRequireTest < ConsoleTestCase
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

    class CodeRequireTest < ConsoleTestCase
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

  class CommandRecognizeTest < ConsoleTestCase
    def program
      <<~RUBY
       1| a = 1
       2| b = 2
       3| a = b
       4| "foo"
      RUBY
    end

    def test_is_command
      commands = { 'n' => true, 'p' => true }
      command_expressions = ['n', 'p 1', " n \n", " p 1 \n", 'n + 1', 'p == 1']
      non_command_expressions = ["n\n\n", 'n = 1', 'n ||= 1', 'n =1', "p 1\n.itself"]
      command_expressions.each do |s|
        assert_equal true, DEBUGGER__::Session.command?(s, commands: commands)
      end
      non_command_expressions.each do |s|
        assert_equal false, DEBUGGER__::Session.command?(s, commands: commands)
      end
    end

    def test_assign_expression_conflicting_with_command_treated_as_expression
      run_ruby(program, options: "-r debug/start") do
        assert_line_num(1)
        type 'n'
        assert_line_num(2)
        type '  n  '
        assert_line_num(3)
        type 'n = 123000'
        assert_line_num(3)
        type 'n += 456'
        assert_line_num(3)
        type 'p n'
        assert_line_text('123456')
        type 'next'
        assert_line_num(4)
        type 'c'
      end
    end
  end
end

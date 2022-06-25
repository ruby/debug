# frozen_string_literal: true

require_relative 'support/console_test_case'

module DEBUGGER__
  class PseudoTerminalTest < ConsoleTestCase
    def program
      <<~RUBY
        a = 1
      RUBY
    end

    def test_the_test_fails_when_debugger_exits_early
      assert_raise_message(/Expected all commands\/assertions to be executed/) do
        debug_code(program) do
          type 'continue'
          type 'foo'
        end
      end
    end

    def test_the_test_fails_when_the_script_doesnt_have_line_numbers
      assert_raise_message(/line numbers are required in test script. please update the script with:\n/) do
        debug_code(program) do
          type 'continue'
        end
      end
    end

    def test_the_test_work_when_debuggee_outputs_many_lines
      debug_code ' 1| 300.times{|i| p i}' do
        type 'c'
      end
    end

    def test_the_test_fails_when_the_repl_prompt_does_not_finish_even_though_scenario_is_empty
      assert_raise_message(/Expected the REPL prompt to finish/) do
        debug_code(program) do
        end
      end
    end
  end
end

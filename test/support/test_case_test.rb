# frozen_string_literal: true

require_relative 'console_test_case'

module DEBUGGER__
  class PseudoTerminalTest < ConsoleTestCase
    def program
      <<~RUBY
        a = 1
      RUBY
    end

    def test_the_test_fails_when_debugger_exits_early
      assert_raise_message(/Expected all commands\/assertions to be executed/) do
        debug_code(program, remote: false) do
          type 'continue'
          type 'foo'
        end
      end
    end

    def test_the_test_fails_when_the_script_doesnt_have_line_numbers
      assert_raise_message(/line numbers are required in test script. please update the script with:\n/) do
        debug_code(program, remote: false) do
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
        debug_code(program, remote: false) do
        end
      end
    end
  end

  class PseudoTerminalTestForRemoteDebuggee < ConsoleTestCase
    def program
      <<~RUBY
        1| def a
        2| end
        3|
        4| loop{
        5|   a()
        6| }
      RUBY
    end

    def steps
      Proc.new{
        type 'quit'
        type 'y'
      }
    end

    def test_the_test_fails_when_debuggee_on_unix_domain_socket_mode_doesnt_exist_after_scenarios
      assert_raise_message(/Expected the debuggee program to finish/) do
        prepare_test_environment(program, steps) do
          debug_code_on_unix_domain_socket()
        end
      end
    end

    def test_the_test_fails_when_debuggee_on_tcpip_mode_doesnt_exist_after_scenarios
      assert_raise_message(/Expected the debuggee program to finish/) do
        prepare_test_environment(program, steps) do
          debug_code_on_tcpip()
        end
      end
    end
  end

  class PseudoTerminalTerminationTestForRemoteDebuggee < ConsoleTestCase
    def program
      <<~RUBY
        a = 1
      RUBY
    end

    def test_the_test_unix_domain_socket_mode_fails_when_debugger_exits_early
      steps = Proc.new{
        type 'continue'
        type 'foo'
      }

      assert_raise_message(/Expected all commands\/assertions to be executed/) do
        prepare_test_environment(program, steps) do
          debug_code_on_unix_domain_socket()
        end
      end
    end

    def test_the_test_tcpip_mode_fails_when_debugger_exits_early
      steps = Proc.new{
        type 'continue'
        type 'foo'
      }

      assert_raise_message(/Expected all commands\/assertions to be executed/) do
        prepare_test_environment(program, steps) do
          debug_code_on_tcpip()
        end
      end
    end

    def test_the_test_unix_domain_socket_mode_fails_when_the_repl_prompt_does_not_finish_even_though_scenario_is_empty
      steps = Proc.new{}
      assert_raise_message(/Expected the REPL prompt to finish/) do
        prepare_test_environment(program, steps) do
          debug_code_on_unix_domain_socket()
        end
      end
    end

    def test_the_test_tcpip_mode_fails_when_the_repl_prompt_does_not_finish_even_though_scenario_is_empty
      steps = Proc.new{}
      assert_raise_message(/Expected the REPL prompt to finish/) do
        prepare_test_environment(program, steps) do
          debug_code_on_unix_domain_socket()
        end
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__
  class EvalTest < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| a = 2
      2| b = 3
      3| c = 1
      4| d = 4
      5| e = 5
      6| f = 6
    RUBY

    def test_eval_evaluates_arithmetic_expressions
      run_protocol_scenario PROGRAM do
        req_add_breakpoint 5
        req_continue
        assert_repl_result 2, expression: 'a'
        assert_repl_result 4, expression: 'd'
        assert_repl_result 3, expression: '1+2'
        req_terminate_debuggee
      end
    end
  end
end

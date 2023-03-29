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

    def test_eval_evaluates_expressions
      run_protocol_scenario PROGRAM do
        req_add_breakpoint 5
        req_continue
        assert_repl_result({value: '2', type: 'Integer'}, 'a')
        assert_repl_result({value: '4', type: 'Integer'}, 'd')
        assert_repl_result({value: '3', type: 'Integer'}, '1+2')
        assert_repl_result({value: 'false', type: 'FalseClass'}, 'a == 1')
        req_terminate_debuggee
      end
    end

    def test_eval_executes_commands
      run_protocol_scenario PROGRAM, cdp: false do
        req_add_breakpoint 3
        req_continue
        assert_repl_result({value: '(rdbg:command) b 5 ;; b 6', type: nil}, ",b 5 ;; b 6")
        req_continue
        assert_line_num 5
        req_continue
        assert_line_num 6
        req_terminate_debuggee
      end
    end
  end

  class EvaluateOnSomeFramesTest < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| a = 2
      2| def foo
      3|   a = 4
      4| end
      5| foo
    RUBY

    def test_eval_evaluates_arithmetic_expressions
      run_protocol_scenario PROGRAM do
        req_add_breakpoint 4
        req_continue
        assert_repl_result({value: '4', type: 'Integer'}, 'a', frame_idx: 0)
        assert_repl_result({value: '2', type: 'Integer'}, 'a', frame_idx: 1)
        req_terminate_debuggee
      end
    end
  end
end

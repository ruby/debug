# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__
  class CatchTest < ProtocolTestCase
    PROGRAM = <<~RUBY
     1| def foo
     2|   a = 1
     3|   raise "foo"
     4| end
     5|
     6| foo
    RUBY

    def test_set_exception_breakpoints_sets_exception_breakpoints
      run_protocol_scenario PROGRAM do
        req_set_exception_breakpoints([{ name: "RuntimeError" }])
        req_continue
        assert_line_num 3
        req_terminate_debuggee
      end
    end

    def test_set_exception_breakpoints_unsets_exception_breakpoints
      run_protocol_scenario PROGRAM, cdp: false do
        req_set_exception_breakpoints([{ name: "RuntimeError" }])
        req_set_exception_breakpoints([])
        req_continue
      end
    end

    def test_set_exception_breakpoints_accepts_condition
      run_protocol_scenario PROGRAM, cdp: false do
        req_set_exception_breakpoints([{ name: "RuntimeError", condition: "a == 2" }])
        req_continue
      end

      run_protocol_scenario PROGRAM, cdp: false do
        req_set_exception_breakpoints([{ name: "RuntimeError", condition: "a == 1" }])
        req_continue
        assert_line_num 3
        req_terminate_debuggee
      end
    end
  end
end

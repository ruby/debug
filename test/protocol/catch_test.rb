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
        req_terminate_debuggee
      end
    end

    def test_set_exception_breakpoints_accepts_condition
      run_protocol_scenario PROGRAM, cdp: false do
        req_set_exception_breakpoints([{ name: "RuntimeError", condition: "a == 2" }])
        req_terminate_debuggee
      end

      run_protocol_scenario PROGRAM, cdp: false do
        req_set_exception_breakpoints([{ name: "RuntimeError", condition: "a == 1" }])
        req_continue
        assert_line_num 3
        req_terminate_debuggee
      end
    end
  end

  class CatchExceptionOptionsTest < ProtocolTestCase
    PROGRAM = <<~RUBY
     1| class MyError < StandardError; end
     2| class MySubError < MyError; end
     3|
     4| def foo
     5|   raise MySubError, "foo"
     6| end
     7|
     8| foo
    RUBY

    def test_exception_options_catches_a_specific_exception_class
      run_protocol_scenario PROGRAM, cdp: false do
        send_dap_request 'setExceptionBreakpoints', filters: [],
          exceptionOptions: [{ path: [{ names: ["MyError"] }], breakMode: "always" }]
        req_continue
        assert_line_num 5
        req_terminate_debuggee
      end
    end

    def test_exception_options_with_break_mode_never_does_not_register_a_breakpoint
      run_protocol_scenario PROGRAM, cdp: false do
        send_dap_request 'setExceptionBreakpoints', filters: [],
          exceptionOptions: [{ path: [{ names: ["MyError"] }], breakMode: "never" }]
        req_terminate_debuggee
      end
    end

    def test_exception_options_breakpoints_are_replaced_by_the_next_request
      run_protocol_scenario PROGRAM, cdp: false do
        send_dap_request 'setExceptionBreakpoints', filters: [],
          exceptionOptions: [{ path: [{ names: ["MyError"] }], breakMode: "always" }]
        send_dap_request 'setExceptionBreakpoints', filters: []
        req_terminate_debuggee
      end
    end

    def test_exception_options_reports_unsupported_negated_segments
      run_protocol_scenario PROGRAM, cdp: false do
        res = send_dap_request 'setExceptionBreakpoints', filters: [],
          exceptionOptions: [{ path: [{ negate: true, names: ["MyError"] }], breakMode: "always" }]
        assert_equal false, res.dig(:body, :breakpoints, 0, :verified)
        req_terminate_debuggee
      end
    end
  end
end

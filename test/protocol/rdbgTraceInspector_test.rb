# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__
  class RdbgTraceInspectorTest < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| def foo
      2|   'bar'
      3| end
      4| foo
      5| foo
    RUBY

    def test_defaut_setting
      run_protocol_scenario(PROGRAM, cdp: false) do
        req_rdbgTraceInspector_enable
        req_add_breakpoint 5
        req_continue
        assert_rdbgTraceInspector_collect_result(
          [
            {
              returnValue: "\"bar\"",
              name: 'Object#foo',
              location: {
                line: 3,
              }
            },
            {
              name: 'Object#foo',
              location: {
                line: 1,
              }
            },
            {
              location: {
                line: 4,
              }
            },
          ]
        )
        req_terminate_debuggee
      end
    end

    def test_call_event
      run_protocol_scenario(PROGRAM, cdp: false) do
        req_rdbgTraceInspector_enable(events: ['call'])
        req_add_breakpoint 5
        req_continue
        assert_rdbgTraceInspector_collect_result(
          [
            {
              name: 'Object#foo',
              location: {
                line: 1,
              }
            },
          ]
        )
        req_terminate_debuggee
      end
    end

    def test_return_event
      run_protocol_scenario(PROGRAM, cdp: false) do
        req_rdbgTraceInspector_enable(events: ['return'])
        req_add_breakpoint 5
        req_continue
        assert_rdbgTraceInspector_collect_result(
          [
            {
              returnValue: "\"bar\"",
              name: 'Object#foo',
              location: {
                line: 3,
              }
            },
          ]
        )
        req_terminate_debuggee
      end
    end

    def test_line_event
      run_protocol_scenario(PROGRAM, cdp: false) do
        req_rdbgTraceInspector_enable(events: ['line'])
        req_add_breakpoint 5
        req_continue
        assert_rdbgTraceInspector_collect_result(
          [
            {
              location: {
                line: 4,
              }
            },
          ]
        )
        req_terminate_debuggee
      end
    end

    def test_restart_trace
      run_protocol_scenario(PROGRAM, cdp: false) do
        req_rdbgTraceInspector_enable
        req_rdbgTraceInspector_disable
        req_rdbgTraceInspector_enable(events: ['line'])
        req_add_breakpoint 5
        req_continue
        assert_rdbgTraceInspector_collect_result(
          [
            {
              location: {
                line: 4,
              }
            },
          ]
        )
        req_terminate_debuggee
      end
    end
  end
end

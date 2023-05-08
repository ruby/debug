# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__
  class RdbgTraceInspectorTraceTest < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| def foo
      2|   'bar'
      3| end
      4| foo
      5| foo
    RUBY

    def test_defaut_setting
      DEBUGGER__::INITIALIZE_DAP_MSGS[1][:arguments][:rdbgExtensions] = ["traceInspector"]
      run_protocol_scenario(PROGRAM, cdp: false) do
        req_rdbgTraceInspector_trace_enable
        req_add_breakpoint 5
        req_continue
        assert_rdbgTraceInspector_trace_collect_result(
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
    ensure
      DEBUGGER__::INITIALIZE_DAP_MSGS[1][:arguments].delete :rdbgExtensions
    end

    def test_call_event
      DEBUGGER__::INITIALIZE_DAP_MSGS[1][:arguments][:rdbgExtensions] = ["traceInspector"]
      run_protocol_scenario(PROGRAM, cdp: false) do
        req_rdbgTraceInspector_trace_enable(events: ['traceCall'])
        req_add_breakpoint 5
        req_continue
        assert_rdbgTraceInspector_trace_collect_result(
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
    ensure
      DEBUGGER__::INITIALIZE_DAP_MSGS[1][:arguments].delete :rdbgExtensions
    end

    def test_return_event
      DEBUGGER__::INITIALIZE_DAP_MSGS[1][:arguments][:rdbgExtensions] = ["traceInspector"]
      run_protocol_scenario(PROGRAM, cdp: false) do
        req_rdbgTraceInspector_trace_enable(events: ['traceReturn'])
        req_add_breakpoint 5
        req_continue
        assert_rdbgTraceInspector_trace_collect_result(
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
    ensure
      DEBUGGER__::INITIALIZE_DAP_MSGS[1][:arguments].delete :rdbgExtensions
    end

    def test_line_event
      DEBUGGER__::INITIALIZE_DAP_MSGS[1][:arguments][:rdbgExtensions] = ["traceInspector"]
      run_protocol_scenario(PROGRAM, cdp: false) do
        req_rdbgTraceInspector_trace_enable(events: ['traceLine'])
        req_add_breakpoint 5
        req_continue
        assert_rdbgTraceInspector_trace_collect_result(
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
    ensure
      DEBUGGER__::INITIALIZE_DAP_MSGS[1][:arguments].delete :rdbgExtensions
    end

    def test_restart_trace
      DEBUGGER__::INITIALIZE_DAP_MSGS[1][:arguments][:rdbgExtensions] = ["traceInspector"]
      run_protocol_scenario(PROGRAM, cdp: false) do
        req_rdbgTraceInspector_trace_enable
        req_rdbgTraceInspector_trace_disable
        req_rdbgTraceInspector_trace_enable(events: ['traceLine'])
        req_add_breakpoint 5
        req_continue
        assert_rdbgTraceInspector_trace_collect_result(
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
    ensure
      DEBUGGER__::INITIALIZE_DAP_MSGS[1][:arguments].delete :rdbgExtensions
    end
  end

  class RdbgTraceInspectorRecordTest < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| module Foo
      2|   class Bar
      3|     def self.a
      4|       "hello"
      5|     end
      6|   end
      7|   Bar.a
      8|   bar = Bar.new
      9| end
    RUBY

    def test_defaut_setting
      DEBUGGER__::INITIALIZE_DAP_MSGS[1][:arguments][:rdbgExtensions] = ["traceInspector"]
      run_protocol_scenario(PROGRAM, cdp: false) do
        req_rdbgTraceInspector_record_enable
        req_add_breakpoint 5
        req_continue
        assert_rdbgTraceInspector_record_collect_result(
          [
            {
              name: "<module:Foo>",
              location: {
                line: 2,
              }
            },
            {
              name: "<class:Bar>",
              location: {
                line: 3,
              }
            }
          ]
        )
        req_rdbgTraceInspector_record_step_back 4
        assert_line_num 2
        req_rdbgTraceInspector_record_step 1
        assert_line_num 3
        req_terminate_debuggee
      end
    ensure
      DEBUGGER__::INITIALIZE_DAP_MSGS[1][:arguments].delete :rdbgExtensions
    end

    def test_restart_trace
      DEBUGGER__::INITIALIZE_DAP_MSGS[1][:arguments][:rdbgExtensions] = ["traceInspector"]
      run_protocol_scenario(PROGRAM, cdp: false) do
        req_rdbgTraceInspector_record_enable
        req_rdbgTraceInspector_record_disable
        req_rdbgTraceInspector_record_enable
        req_add_breakpoint 5
        req_continue
        assert_rdbgTraceInspector_record_collect_result(
          [
            {
              name: "<module:Foo>",
              location: {
                line: 2,
              }
            },
            {
              name: "<class:Bar>",
              location: {
                line: 3,
              }
            }
          ]
        )
        req_rdbgTraceInspector_record_step_back 4
        assert_line_num 2
        req_rdbgTraceInspector_record_step 1
        assert_line_num 3
        req_terminate_debuggee
      end
    ensure
      DEBUGGER__::INITIALIZE_DAP_MSGS[1][:arguments].delete :rdbgExtensions
    end
  end
end

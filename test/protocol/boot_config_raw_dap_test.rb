# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__

  class BootConfigTest1638611290 < TestCase
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

    def test_boot_configuration_works_correctly
      run_dap_scenario PROGRAM do
        [
          *INITIALIZE_DAP_MSGS,
          {
            seq: 1,
            type: "response",
            command: "initialize",
            request_seq: 1,
            success: true,
            message: "Success",
            body: {
              supportsConfigurationDoneRequest: true,
              supportsFunctionBreakpoints: true,
              supportsConditionalBreakpoints: true,
              supportTerminateDebuggee: true,
              supportsTerminateRequest: true,
              exceptionBreakpointFilters: [
                {
                  filter: "any",
                  label: "rescue any exception"
                },
                {
                  filter: "RuntimeError",
                  label: "rescue RuntimeError",
                  default: true
                }
              ],
              supportsExceptionFilterOptions: true,
              supportsStepBack: true,
              supportsEvaluateForHovers: true
            }
          },
          {
            seq: 2,
            type: "event",
            event: "initialized"
          },
          {
            seq: 3,
            type: "response",
            command: "attach",
            request_seq: 2,
            success: true,
            message: "Success"
          },
          {
            seq: 4,
            type: "response",
            command: "setFunctionBreakpoints",
            request_seq: 3,
            success: true,
            message: "Success"
          },
          {
            seq: 5,
            type: "response",
            command: "setExceptionBreakpoints",
            request_seq: 4,
            success: true,
            message: "Success",
            body: {
              breakpoints: [
                {
                  verified: true,
                  message: /#<DEBUGGER__::CatchBreakpoint:.*/
                }
              ]
            }
          },
          {
            seq: 6,
            type: "response",
            command: "configurationDone",
            request_seq: 5,
            success: true,
            message: "Success"
          },
          {
            seq: 7,
            type: "event",
            event: "stopped",
            body: {
              reason: "pause",
              threadId: 1,
              allThreadsStopped: true
            }
          },
          {
            seq: 6,
            command: "threads",
            type: "request"
          },
          {
            seq: 8,
            type: "response",
            command: "threads",
            request_seq: 6,
            success: true,
            message: "Success",
            body: {
              threads: [
                {
                  id: 1,
                  name: "#1 #{temp_file_path}:1:in `<main>'"
                }
              ]
            }
          },
          {
            seq: 7,
            command: "threads",
            type: "request"
          },
          {
            seq: 9,
            type: "response",
            command: "threads",
            request_seq: 7,
            success: true,
            message: "Success",
            body: {
              threads: [
                {
                  id: 1,
                  name: "#1 #{temp_file_path}:1:in `<main>'"
                }
              ]
            }
          },
          {
            seq: 8,
            command: "stackTrace",
            arguments: {
              threadId: 1,
              startFrame: 0,
              levels: 20
            },
            type: "request"
          },
          {
            seq: 10,
            type: "response",
            command: "stackTrace",
            request_seq: 8,
            success: true,
            message: "Success",
            body: {
              stackFrames: [
                {
                  name: "<main>",
                  line: 1,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 1
                }
              ]
            }
          },
          {
            seq: 9,
            command: "scopes",
            arguments: {
              frameId: 1
            },
            type: "request"
          },
          {
            seq: 11,
            type: "response",
            command: "scopes",
            request_seq: 9,
            success: true,
            message: "Success",
            body: {
              scopes: [
                {
                  name: "Local variables",
                  presentationHint: "locals",
                  namedVariables: /\d+/,
                  indexedVariables: 0,
                  expensive: false,
                  variablesReference: 2
                },
                {
                  name: "Global variables",
                  presentationHint: "globals",
                  variablesReference: 1,
                  namedVariables: /\d+/,
                  indexedVariables: 0,
                  expensive: false
                }
              ]
            }
          },
          {
            seq: 10,
            command: "variables",
            arguments: {
              variablesReference: 2
            },
            type: "request"
          },
          {
            seq: 12,
            type: "response",
            command: "variables",
            request_seq: 10,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "%self",
                  value: "main",
                  type: "Object",
                  variablesReference: 3,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 11,
            command: "continue",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 13,
            type: "response",
            command: "continue",
            request_seq: 11,
            success: true,
            message: "Success",
            body: {
              allThreadsContinued: true
            }
          }
        ]
      end
    end
  end
end

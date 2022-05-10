# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__

  class DetachTest1639218122 < TestCase
    PROGRAM = <<~RUBY
       1| module Foo
       2|   class Bar
       3|     def self.a
       4|       "hello"
       5|     end
       6|   end
       7|   loop do
       8|     b = 1
       9|   end
      10|   Bar.a
      11|   bar = Bar.new
      12| end
    RUBY

    def test_1639218122
      run_dap_scenario PROGRAM do
        [
          *INITIALIZE_DAP_MSGS,
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
                  name: /#1 .*/
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
                  name: /#1 .*/
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
            command: "disconnect",
            arguments: {
              restart: false,
              terminateDebuggee: false
            },
            type: "request"
          },
          {
            seq: 13,
            type: "response",
            command: "disconnect",
            request_seq: 11,
            success: true,
            message: "Success"
          },
          {
            seq: 1,
            command: "initialize",
            arguments: {
              clientID: "vscode",
              clientName: "Visual Studio Code",
              adapterID: "rdbg",
              pathFormat: "path",
              linesStartAt1: true,
              columnsStartAt1: true,
              supportsVariableType: true,
              supportsVariablePaging: true,
              supportsRunInTerminalRequest: true,
              locale: "en-us",
              supportsProgressReporting: true,
              supportsInvalidatedEvent: true,
              supportsMemoryReferences: true
            },
            type: "request"
          },
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
                  label: "rescue RuntimeError"
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
            seq: 2,
            command: "attach",
            arguments: {
              type: "rdbg",
              name: "Attach with rdbg",
              request: "attach",
              rdbgPath: /#{File.expand_path('../../exe/rdbg', __dir__)}/,
              debugPort: "/var/folders/5j/z2c9zm7124q81f_py4xmd3scp7w9j7/T/ruby-debug-sock-746464807/ruby-debug-s15236-55231",
              autoAttach: true,
              __configurationTarget: 5,
              __sessionId: "e3ff75ee-d35c-49a4-9520-ac70bd14867d"
            },
            type: "request"
          },
          {
            seq: 3,
            type: "event",
            event: "stopped",
            body: {
              reason: "pause",
              threadId: 1,
              allThreadsStopped: true
            }
          },
          {
            seq: 4,
            type: "response",
            command: "attach",
            request_seq: 2,
            success: true,
            message: "Success"
          },
          {
            seq: 3,
            command: "setFunctionBreakpoints",
            arguments: {
              breakpoints: [

              ]
            },
            type: "request"
          },
          {
            seq: 5,
            type: "response",
            command: "setFunctionBreakpoints",
            request_seq: 3,
            success: true,
            message: "Success"
          },
          {
            seq: 4,
            command: "threads",
            type: "request"
          },
          {
            seq: 6,
            type: "response",
            command: "threads",
            request_seq: 4,
            success: true,
            message: "Success",
            body: {
              threads: [
                {
                  id: 1,
                  name: /#1 .*/
                }
              ]
            }
          },
          {
            seq: 5,
            command: "setExceptionBreakpoints",
            arguments: {
              filters: [

              ],
              filterOptions: [
                {
                  filterId: "RuntimeError"
                }
              ]
            },
            type: "request"
          },
          {
            seq: 7,
            type: "response",
            command: "setExceptionBreakpoints",
            request_seq: 5,
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
            command: "stackTrace",
            arguments: {
              threadId: 1,
              startFrame: 0,
              levels: 20
            },
            type: "request"
          },
          {
            seq: 8,
            type: "response",
            command: "stackTrace",
            request_seq: 6,
            success: true,
            message: "Success",
            body: {
              stackFrames: [
                {
                  name: "block in <module:Foo>",
                  line: 9,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 2
                },
                {
                  name: "[C] Kernel#loop",
                  line: 7,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 3
                },
                {
                  name: "<module:Foo>",
                  line: 7,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 4
                },
                {
                  name: "<main>",
                  line: 1,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 5
                }
              ]
            }
          },
          {
            seq: 7,
            command: "configurationDone",
            type: "request"
          },
          {
            seq: 9,
            type: "response",
            command: "configurationDone",
            request_seq: 7,
            success: true,
            message: "Success"
          },
          {
            seq: 10,
            type: "event",
            event: "stopped",
            body: {
              reason: "pause",
              threadId: 1,
              allThreadsStopped: true
            }
          },
          {
            seq: 8,
            command: "threads",
            type: "request"
          },
          {
            seq: 11,
            type: "response",
            command: "threads",
            request_seq: 8,
            success: true,
            message: "Success",
            body: {
              threads: [
                {
                  id: 1,
                  name: /#1 .*/
                }
              ]
            }
          },
          {
            seq: 9,
            command: "threads",
            type: "request"
          },
          {
            seq: 12,
            type: "response",
            command: "threads",
            request_seq: 9,
            success: true,
            message: "Success",
            body: {
              threads: [
                {
                  id: 1,
                  name: /#1 .*/
                }
              ]
            }
          },
          {
            seq: 10,
            command: "stackTrace",
            arguments: {
              threadId: 1,
              startFrame: 0,
              levels: 20
            },
            type: "request"
          },
          {
            seq: 13,
            type: "response",
            command: "stackTrace",
            request_seq: 10,
            success: true,
            message: "Success",
            body: {
              stackFrames: [
                {
                  name: "block in <module:Foo>",
                  line: 9,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 6
                },
                {
                  name: "[C] Kernel#loop",
                  line: 7,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 7
                },
                {
                  name: "<module:Foo>",
                  line: 7,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 8
                },
                {
                  name: "<main>",
                  line: 1,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 9
                }
              ]
            }
          },
          {
            seq: 11,
            command: "scopes",
            arguments: {
              frameId: 6
            },
            type: "request"
          },
          {
            seq: 14,
            type: "response",
            command: "scopes",
            request_seq: 11,
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
                  variablesReference: 4
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
            seq: 12,
            command: "variables",
            arguments: {
              variablesReference: 4
            },
            type: "request"
          },
          {
            seq: 15,
            type: "response",
            command: "variables",
            request_seq: 12,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "%self",
                  value: "Foo",
                  type: "Module",
                  variablesReference: 5,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "b",
                  value: "1",
                  type: "Integer",
                  variablesReference: 6,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "bar",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 7,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 13,
            command: "disconnect",
            arguments: {
              restart: false,
              terminateDebuggee: false
            },
            type: "request"
          },
          {
            seq: 16,
            type: "response",
            command: "disconnect",
            request_seq: 13,
            success: true,
            message: "Success"
          }
        ]
      end
    end
  end
end

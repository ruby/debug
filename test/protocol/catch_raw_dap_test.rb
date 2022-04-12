# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class CatchTest1643891417 < TestCase
    PROGRAM = <<~RUBY
      1| module Foo
      2|   class Bar
      3|     def self.a
      4|       raise 'foo'
      5|     end
      6|   end
      7|   Bar.a
      8|   bar = Bar.new
      9| end
    RUBY

    def test_catching_runtime_error_works_correctly_1643891417
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
          },
          {
            seq: 14,
            type: "event",
            event: "stopped",
            body: {
              reason: "exception",
              description: "#<RuntimeError: foo> is raised.",
              text: "#<RuntimeError: foo> is raised.",
              threadId: 1,
              allThreadsStopped: true
            }
          },
          {
            seq: 12,
            command: "threads",
            type: "request"
          },
          {
            seq: 15,
            type: "response",
            command: "threads",
            request_seq: 12,
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
            seq: 13,
            command: "stackTrace",
            arguments: {
              threadId: 1,
              startFrame: 0,
              levels: 20
            },
            type: "request"
          },
          {
            seq: 16,
            type: "response",
            command: "stackTrace",
            request_seq: 13,
            success: true,
            message: "Success",
            body: {
              stackFrames: [
                {
                  name: "Foo::Bar.a",
                  line: 4,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 2
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
                  id: 3
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
                  id: 4
                }
              ]
            }
          },
          {
            seq: 14,
            command: "scopes",
            arguments: {
              frameId: 2
            },
            type: "request"
          },
          {
            seq: 17,
            type: "response",
            command: "scopes",
            request_seq: 14,
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
            seq: 15,
            command: "variables",
            arguments: {
              variablesReference: 4
            },
            type: "request"
          },
          {
            seq: 18,
            type: "response",
            command: "variables",
            request_seq: 15,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "%self",
                  value: "Foo::Bar",
                  type: "Class",
                  variablesReference: 5,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "_raised",
                  value: "#<RuntimeError: foo>",
                  type: "RuntimeError",
                  variablesReference: 6,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 16,
            command: "continue",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 19,
            type: "response",
            command: "continue",
            request_seq: 16,
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

  class CatchTest1643892185 < TestCase
    PROGRAM = <<~RUBY
      1| module Foo
      2|   class Bar
      3|     def self.a
      4|       1 / 0
      5|     end
      6|   end
      7|   Bar.a
      8|   bar = Bar.new
      9| end
    RUBY

    def test_catching_any_exception_works_correctly
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
            command: "setExceptionBreakpoints",
            arguments: {
              filters: [

              ],
              filterOptions: [
                {
                  filterId: "any"
                },
                {
                  filterId: "RuntimeError"
                }
              ]
            },
            type: "request"
          },
          {
            seq: 13,
            type: "response",
            command: "setExceptionBreakpoints",
            request_seq: 11,
            success: true,
            message: "Success",
            body: {
              breakpoints: [
                {
                  verified: true,
                  message: /#<DEBUGGER__::CatchBreakpoint:.*/
                },
                {
                  verified: true,
                  message: /#<DEBUGGER__::CatchBreakpoint:.*/
                }
              ]
            }
          },
          {
            seq: 12,
            command: "continue",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 14,
            type: "response",
            command: "continue",
            request_seq: 12,
            success: true,
            message: "Success",
            body: {
              allThreadsContinued: true
            }
          },
          {
            seq: 15,
            type: "event",
            event: "stopped",
            body: {
              reason: "exception",
              description: "#<ZeroDivisionError: divided by 0> is raised.",
              text: "#<ZeroDivisionError: divided by 0> is raised.",
              threadId: 1,
              allThreadsStopped: true
            }
          },
          {
            seq: 13,
            command: "threads",
            type: "request"
          },
          {
            seq: 16,
            type: "response",
            command: "threads",
            request_seq: 13,
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
            seq: 14,
            command: "stackTrace",
            arguments: {
              threadId: 1,
              startFrame: 0,
              levels: 20
            },
            type: "request"
          },
          {
            seq: 17,
            type: "response",
            command: "stackTrace",
            request_seq: 14,
            success: true,
            message: "Success",
            body: {
              stackFrames: [
                {
                  name: "[C] Integer#/",
                  line: 4,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 2
                },
                {
                  name: "Foo::Bar.a",
                  line: 4,
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
            seq: 15,
            command: "scopes",
            arguments: {
              frameId: 2
            },
            type: "request"
          },
          {
            seq: 18,
            type: "response",
            command: "scopes",
            request_seq: 15,
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
            seq: 16,
            command: "variables",
            arguments: {
              variablesReference: 4
            },
            type: "request"
          },
          {
            seq: 19,
            type: "response",
            command: "variables",
            request_seq: 16,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "%self",
                  value: "1",
                  type: "Integer",
                  variablesReference: 5,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "_raised",
                  value: "#<ZeroDivisionError: divided by 0>",
                  type: "ZeroDivisionError",
                  variablesReference: 6,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 17,
            command: "continue",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 20,
            type: "response",
            command: "continue",
            request_seq: 17,
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

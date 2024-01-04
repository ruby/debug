# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__

  class StepBackTest1638698086 < ProtocolTestCase
    PROGRAM = <<~RUBY
       1| binding.b do: 'record on'
       2|
       3| module Foo
       4|   class Bar
       5|     def self.a
       6|       "hello"
       7|     end
       8|   end
       9|   Bar.a
      10|   bar = Bar.new
      11| end
    RUBY

    def test_step_back_works_correctly
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
                  expensive: false,
                  variablesReference: 2
                },
                {
                  name: "Global variables",
                  presentationHint: "globals",
                  variablesReference: 1,
                  namedVariables: /\d+/,
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
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 11,
            command: "setBreakpoints",
            arguments: {
              source: {
                name: "target.rb",
                path: temp_file_path,
                sourceReference: 0
              },
              lines: [
                9
              ],
              breakpoints: [
                {
                  line: 9
                }
              ],
              sourceModified: false
            },
            type: "request"
          },
          {
            seq: 13,
            type: "response",
            command: "setBreakpoints",
            request_seq: 11,
            success: true,
            message: "Success",
            body: {
              breakpoints: [
                {
                  verified: true
                }
              ]
            }
          },
          {
            seq: 12,
            command: "evaluate",
            arguments: {
              expression: "do",
              frameId: 1,
              context: "hover"
            },
            type: "request"
          },
          {
            seq: 14,
            type: "response",
            command: "evaluate",
            request_seq: 12,
            success: false,
            message: "Error: Can not evaluate: \"do\""
          },
          {
            seq: 13,
            command: "continue",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 15,
            type: "response",
            command: "continue",
            request_seq: 13,
            success: true,
            message: "Success",
            body: {
              allThreadsContinued: true
            }
          },
          {
            seq: 16,
            type: "event",
            event: "stopped",
            body: {
              reason: "breakpoint",
              description: "temporary bp",
              text: "temporary bp",
              threadId: 1,
              allThreadsStopped: true
            }
          },
          {
            seq: 17,
            type: "event",
            event: "stopped",
            body: {
              reason: "breakpoint",
              description: / BP - Line  .*/,
              text: / BP - Line  .*/,
              threadId: 1,
              allThreadsStopped: true
            }
          },
          {
            seq: 14,
            command: "threads",
            type: "request"
          },
          {
            seq: 18,
            type: "response",
            command: "threads",
            request_seq: 14,
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
            seq: 15,
            command: "threads",
            type: "request"
          },
          {
            seq: 19,
            type: "response",
            command: "threads",
            request_seq: 15,
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
            seq: 16,
            command: "stackTrace",
            arguments: {
              threadId: 1,
              startFrame: 0,
              levels: 20
            },
            type: "request"
          },
          {
            seq: 20,
            type: "response",
            command: "stackTrace",
            request_seq: 16,
            success: true,
            message: "Success",
            body: {
              stackFrames: [
                {
                  name: "<module:Foo>",
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
                  name: "<main>",
                  line: 3,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 3
                }
              ]
            }
          },
          {
            seq: 17,
            command: "stackTrace",
            arguments: {
              threadId: 1,
              startFrame: 0,
              levels: 20
            },
            type: "request"
          },
          {
            seq: 21,
            type: "response",
            command: "stackTrace",
            request_seq: 17,
            success: true,
            message: "Success",
            body: {
              stackFrames: [
                {
                  name: "<module:Foo>",
                  line: 9,
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
                  line: 3,
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
            seq: 18,
            command: "scopes",
            arguments: {
              frameId: 4
            },
            type: "request"
          },
          {
            seq: 22,
            type: "response",
            command: "scopes",
            request_seq: 18,
            success: true,
            message: "Success",
            body: {
              scopes: [
                {
                  name: "Local variables",
                  presentationHint: "locals",
                  namedVariables: /\d+/,
                  expensive: false,
                  variablesReference: 4
                },
                {
                  name: "Global variables",
                  presentationHint: "globals",
                  variablesReference: 1,
                  namedVariables: /\d+/,
                  expensive: false
                }
              ]
            }
          },
          {
            seq: 19,
            command: "variables",
            arguments: {
              variablesReference: 4
            },
            type: "request"
          },
          {
            seq: 23,
            type: "response",
            command: "variables",
            request_seq: 19,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "%self",
                  value: "Foo",
                  type: "Module",
                  variablesReference: 5,
                  namedVariables: /\d+/
                },
                {
                  name: "bar",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 6,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 20,
            command: "stepBack",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 24,
            type: "event",
            event: "stopped",
            body: {
              reason: "step",
              threadId: 1,
              allThreadsStopped: true
            }
          },
          {
            seq: 21,
            command: "threads",
            type: "request"
          },
          {
            seq: 25,
            type: "response",
            command: "threads",
            request_seq: 21,
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
            seq: 22,
            command: "stackTrace",
            arguments: {
              threadId: 1,
              startFrame: 0,
              levels: 20
            },
            type: "request"
          },
          {
            seq: 26,
            type: "response",
            command: "stackTrace",
            request_seq: 22,
            success: true,
            message: "Success",
            body: {
              stackFrames: [
                {
                  name: "<module:Foo>",
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
                  name: "<main>",
                  line: 3,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 7
                }
              ]
            }
          },
          {
            seq: 23,
            command: "scopes",
            arguments: {
              frameId: 6
            },
            type: "request"
          },
          {
            seq: 27,
            type: "response",
            command: "scopes",
            request_seq: 23,
            success: true,
            message: "Success",
            body: {
              scopes: [
                {
                  name: "Local variables",
                  presentationHint: "locals",
                  namedVariables: /\d+/,
                  expensive: false,
                  variablesReference: 7
                },
                {
                  name: "Global variables",
                  presentationHint: "globals",
                  variablesReference: 1,
                  namedVariables: /\d+/,
                  expensive: false
                }
              ]
            }
          },
          {
            seq: 24,
            command: "variables",
            arguments: {
              variablesReference: 7
            },
            type: "request"
          },
          {
            seq: 28,
            type: "response",
            command: "variables",
            request_seq: 24,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "%self",
                  value: "Foo",
                  type: "Module",
                  variablesReference: 8,
                  namedVariables: /\d+/
                },
                {
                  name: "bar",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 9,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 25,
            command: "stepBack",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 29,
            type: "event",
            event: "stopped",
            body: {
              reason: "step",
              threadId: 1,
              allThreadsStopped: true
            }
          },
          {
            seq: 26,
            command: "threads",
            type: "request"
          },
          {
            seq: 30,
            type: "response",
            command: "threads",
            request_seq: 26,
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
            seq: 27,
            command: "stackTrace",
            arguments: {
              threadId: 1,
              startFrame: 0,
              levels: 20
            },
            type: "request"
          },
          {
            seq: 31,
            type: "response",
            command: "stackTrace",
            request_seq: 27,
            success: true,
            message: "Success",
            body: {
              stackFrames: [
                {
                  name: "<class:Bar>",
                  line: 5,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 8
                },
                {
                  name: "<module:Foo>",
                  line: 4,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 9
                },
                {
                  name: "<main>",
                  line: 3,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 10
                }
              ]
            }
          },
          {
            seq: 28,
            command: "scopes",
            arguments: {
              frameId: 8
            },
            type: "request"
          },
          {
            seq: 32,
            type: "response",
            command: "scopes",
            request_seq: 28,
            success: true,
            message: "Success",
            body: {
              scopes: [
                {
                  name: "Local variables",
                  presentationHint: "locals",
                  namedVariables: /\d+/,
                  expensive: false,
                  variablesReference: 10
                },
                {
                  name: "Global variables",
                  presentationHint: "globals",
                  variablesReference: 1,
                  namedVariables: /\d+/,
                  expensive: false
                }
              ]
            }
          },
          {
            seq: 29,
            command: "variables",
            arguments: {
              variablesReference: 9
            },
            type: "request"
          },
          {
            seq: 33,
            type: "response",
            command: "variables",
            request_seq: 29,
            success: true,
            message: "Success",
            body: {
              variables: [

              ]
            }
          },
          {
            seq: 30,
            command: "stepBack",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 34,
            type: "event",
            event: "stopped",
            body: {
              reason: "step",
              threadId: 1,
              allThreadsStopped: true
            }
          },
          {
            seq: 31,
            command: "threads",
            type: "request"
          },
          {
            seq: 35,
            type: "response",
            command: "threads",
            request_seq: 31,
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
            seq: 32,
            command: "stackTrace",
            arguments: {
              threadId: 1,
              startFrame: 0,
              levels: 20
            },
            type: "request"
          },
          {
            seq: 36,
            type: "response",
            command: "stackTrace",
            request_seq: 32,
            success: true,
            message: "Success",
            body: {
              stackFrames: [
                {
                  name: "<module:Foo>",
                  line: 4,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 11
                },
                {
                  name: "<main>",
                  line: 3,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 12
                }
              ]
            }
          },
          {
            seq: 33,
            command: "scopes",
            arguments: {
              frameId: 11
            },
            type: "request"
          },
          {
            seq: 37,
            type: "response",
            command: "scopes",
            request_seq: 33,
            success: true,
            message: "Success",
            body: {
              scopes: [
                {
                  name: "Local variables",
                  presentationHint: "locals",
                  namedVariables: /\d+/,
                  expensive: false,
                  variablesReference: 12
                },
                {
                  name: "Global variables",
                  presentationHint: "globals",
                  variablesReference: 1,
                  namedVariables: /\d+/,
                  expensive: false
                }
              ]
            }
          },
          {
            seq: 34,
            command: "variables",
            arguments: {
              variablesReference: 10
            },
            type: "request"
          },
          {
            seq: 38,
            type: "response",
            command: "variables",
            request_seq: 34,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "%self",
                  value: "Foo",
                  type: "Module",
                  variablesReference: 13,
                  namedVariables: /\d+/
                },
                {
                  name: "bar",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 14,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 35,
            command: "continue",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 39,
            type: "response",
            command: "continue",
            request_seq: 35,
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

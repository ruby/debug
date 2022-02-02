# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  
  class EvalTest1643807667 < TestCase
    PROGRAM = <<~RUBY
      1| a = 2
      2| b = 3
      3| c = 1
      4| d = 4
      5| e = 5
      6| f = 6
    RUBY
    
    def test_eval_works_correctly_1643807667
      run_dap_scenario PROGRAM do
        [
          *INITIALIZE_MSG,
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
                    sourceReference: nil
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
                },
                {
                  name: "a",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 4,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "b",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 5,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "c",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 6,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "d",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 7,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "e",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 8,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "f",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 9,
                  indexedVariables: 0,
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
                sourceReference: nil
              },
              lines: [
                5
              ],
              breakpoints: [
                {
                  line: 5
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
              reason: "breakpoint",
              description: / BP - Line  .*/,
              text: / BP - Line  .*/,
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
                  name: "<main>",
                  line: 5,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: nil
                  },
                  id: 2
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
                  variablesReference: 10
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
              variablesReference: 10
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
                  value: "main",
                  type: "Object",
                  variablesReference: 11,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "a",
                  value: "2",
                  type: "Integer",
                  variablesReference: 12,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "b",
                  value: "3",
                  type: "Integer",
                  variablesReference: 13,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "c",
                  value: "1",
                  type: "Integer",
                  variablesReference: 14,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "d",
                  value: "4",
                  type: "Integer",
                  variablesReference: 15,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "e",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 16,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "f",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 17,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 17,
            command: "completions",
            arguments: {
              frameId: 2,
              text: "a",
              column: 2,
              line: 1
            },
            type: "request"
          },
          {
            seq: 20,
            type: "response",
            command: "completions",
            request_seq: 17,
            success: true,
            message: "Success",
            body: {
              targets: [
                {
                  label: /.*/,
                  text: /.*/
                },
                {
                  label: /.*/,
                  text: /.*/
                },
                {
                  label: /.*/,
                  text: /.*/
                },
                {
                  label: /.*/,
                  text: /.*/
                },
                {
                  label: /.*/,
                  text: /.*/
                },
                {
                  label: /.*/,
                  text: /.*/
                },
                {
                  label: /.*/,
                  text: /.*/
                }
              ]
            }
          },
          {
            seq: 18,
            command: "evaluate",
            arguments: {
              expression: "a",
              frameId: 2,
              context: "repl"
            },
            type: "request"
          },
          {
            seq: 21,
            type: "response",
            command: "evaluate",
            request_seq: 18,
            success: true,
            message: "Success",
            body: {
              type: "Integer",
              variablesReference: 18,
              indexedVariables: 0,
              namedVariables: /\d+/,
              result: "2"
            }
          },
          {
            seq: 19,
            command: "scopes",
            arguments: {
              frameId: 2
            },
            type: "request"
          },
          {
            seq: 22,
            type: "response",
            command: "scopes",
            request_seq: 19,
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
                  variablesReference: 19
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
            seq: 20,
            command: "variables",
            arguments: {
              variablesReference: 19
            },
            type: "request"
          },
          {
            seq: 23,
            type: "response",
            command: "variables",
            request_seq: 20,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "%self",
                  value: "main",
                  type: "Object",
                  variablesReference: 20,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "a",
                  value: "2",
                  type: "Integer",
                  variablesReference: 21,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "b",
                  value: "3",
                  type: "Integer",
                  variablesReference: 22,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "c",
                  value: "1",
                  type: "Integer",
                  variablesReference: 23,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "d",
                  value: "4",
                  type: "Integer",
                  variablesReference: 24,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "e",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 25,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "f",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 26,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 21,
            command: "completions",
            arguments: {
              frameId: 2,
              text: "d",
              column: 2,
              line: 1
            },
            type: "request"
          },
          {
            seq: 24,
            type: "response",
            command: "completions",
            request_seq: 21,
            success: true,
            message: "Success",
            body: {
              targets: [
                {
                  label: /.*/,
                  text: /.*/
                },
                {
                  label: /.*/,
                  text: /.*/
                },
                {
                  label: /.*/,
                  text: /.*/
                },
                {
                  label: /.*/,
                  text: /.*/
                },
                {
                  label: /.*/,
                  text: /.*/
                },
                {
                  label: /.*/,
                  text: /.*/
                },
                {
                  label: /.*/,
                  text: /.*/
                },
                {
                  label: /.*/,
                  text: /.*/
                },
                {
                  label: /.*/,
                  text: /.*/
                }
              ]
            }
          },
          {
            seq: 22,
            command: "evaluate",
            arguments: {
              expression: "d",
              frameId: 2,
              context: "repl"
            },
            type: "request"
          },
          {
            seq: 25,
            type: "response",
            command: "evaluate",
            request_seq: 22,
            success: true,
            message: "Success",
            body: {
              type: "Integer",
              variablesReference: 27,
              indexedVariables: 0,
              namedVariables: /\d+/,
              result: "4"
            }
          },
          {
            seq: 23,
            command: "scopes",
            arguments: {
              frameId: 2
            },
            type: "request"
          },
          {
            seq: 26,
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
                  indexedVariables: 0,
                  expensive: false,
                  variablesReference: 28
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
            seq: 24,
            command: "variables",
            arguments: {
              variablesReference: 28
            },
            type: "request"
          },
          {
            seq: 27,
            type: "response",
            command: "variables",
            request_seq: 24,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "%self",
                  value: "main",
                  type: "Object",
                  variablesReference: 29,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "a",
                  value: "2",
                  type: "Integer",
                  variablesReference: 30,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "b",
                  value: "3",
                  type: "Integer",
                  variablesReference: 31,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "c",
                  value: "1",
                  type: "Integer",
                  variablesReference: 32,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "d",
                  value: "4",
                  type: "Integer",
                  variablesReference: 33,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "e",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 34,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "f",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 35,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 25,
            command: "evaluate",
            arguments: {
              expression: "1 + 2",
              frameId: 2,
              context: "repl"
            },
            type: "request"
          },
          {
            seq: 28,
            type: "response",
            command: "evaluate",
            request_seq: 25,
            success: true,
            message: "Success",
            body: {
              type: "Integer",
              variablesReference: 36,
              indexedVariables: 0,
              namedVariables: /\d+/,
              result: "3"
            }
          },
          {
            seq: 26,
            command: "scopes",
            arguments: {
              frameId: 2
            },
            type: "request"
          },
          {
            seq: 29,
            type: "response",
            command: "scopes",
            request_seq: 26,
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
                  variablesReference: 37
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
            seq: 27,
            command: "variables",
            arguments: {
              variablesReference: 37
            },
            type: "request"
          },
          {
            seq: 30,
            type: "response",
            command: "variables",
            request_seq: 27,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "%self",
                  value: "main",
                  type: "Object",
                  variablesReference: 38,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "a",
                  value: "2",
                  type: "Integer",
                  variablesReference: 39,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "b",
                  value: "3",
                  type: "Integer",
                  variablesReference: 40,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "c",
                  value: "1",
                  type: "Integer",
                  variablesReference: 41,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "d",
                  value: "4",
                  type: "Integer",
                  variablesReference: 42,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "e",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 43,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "f",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 44,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 28,
            command: "continue",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 31,
            type: "response",
            command: "continue",
            request_seq: 28,
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

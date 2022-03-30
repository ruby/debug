# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__

  class WatchTest1643810224 < TestCase
    PROGRAM = <<~RUBY
      1| a = 2
      2| a += 1
      3| a += 1
      4| d = 4
      5| a += 1
      6| e = 5
      7| f = 6
    RUBY

    def test_watch_works_correctly_1643810224
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
                  name: "d",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 5,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "e",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 6,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "f",
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
            seq: 11,
            command: "evaluate",
            arguments: {
              expression: "a",
              frameId: 1,
              context: "watch"
            },
            type: "request"
          },
          {
            seq: 12,
            command: "scopes",
            arguments: {
              frameId: 1
            },
            type: "request"
          },
          {
            seq: 13,
            type: "response",
            command: "evaluate",
            request_seq: 11,
            success: true,
            message: "Success",
            body: {
              type: "NilClass",
              variablesReference: 8,
              indexedVariables: 0,
              namedVariables: /\d+/,
              result: "nil"
            }
          },
          {
            seq: 14,
            type: "response",
            command: "scopes",
            request_seq: 12,
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
                  variablesReference: 9
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
            seq: 13,
            command: "variables",
            arguments: {
              variablesReference: 9
            },
            type: "request"
          },
          {
            seq: 15,
            type: "response",
            command: "variables",
            request_seq: 13,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "%self",
                  value: "main",
                  type: "Object",
                  variablesReference: 10,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "a",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 11,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "d",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 12,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "e",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 13,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "f",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 14,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 14,
            command: "next",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 16,
            type: "response",
            command: "next",
            request_seq: 14,
            success: true,
            message: "Success"
          },
          {
            seq: 17,
            type: "event",
            event: "stopped",
            body: {
              reason: "step",
              threadId: 1,
              allThreadsStopped: true
            }
          },
          {
            seq: 15,
            command: "threads",
            type: "request"
          },
          {
            seq: 18,
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
            seq: 19,
            type: "response",
            command: "stackTrace",
            request_seq: 16,
            success: true,
            message: "Success",
            body: {
              stackFrames: [
                {
                  name: "<main>",
                  line: 2,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 2
                }
              ]
            }
          },
          {
            seq: 17,
            command: "evaluate",
            arguments: {
              expression: "a",
              frameId: 2,
              context: "watch"
            },
            type: "request"
          },
          {
            seq: 20,
            type: "response",
            command: "evaluate",
            request_seq: 17,
            success: true,
            message: "Success",
            body: {
              type: "Integer",
              variablesReference: 15,
              indexedVariables: 0,
              namedVariables: /\d+/,
              result: "2"
            }
          },
          {
            seq: 18,
            command: "scopes",
            arguments: {
              frameId: 2
            },
            type: "request"
          },
          {
            seq: 21,
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
                  indexedVariables: 0,
                  expensive: false,
                  variablesReference: 16
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
            seq: 19,
            command: "variables",
            arguments: {
              variablesReference: 16
            },
            type: "request"
          },
          {
            seq: 22,
            type: "response",
            command: "variables",
            request_seq: 19,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "%self",
                  value: "main",
                  type: "Object",
                  variablesReference: 17,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "a",
                  value: "2",
                  type: "Integer",
                  variablesReference: 18,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "d",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 19,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "e",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 20,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "f",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 21,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 20,
            command: "next",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 23,
            type: "response",
            command: "next",
            request_seq: 20,
            success: true,
            message: "Success"
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
            seq: 23,
            command: "evaluate",
            arguments: {
              expression: "a",
              frameId: 3,
              context: "watch"
            },
            type: "request"
          },
          {
            seq: 27,
            type: "response",
            command: "evaluate",
            request_seq: 23,
            success: true,
            message: "Success",
            body: {
              type: "Integer",
              variablesReference: 22,
              indexedVariables: 0,
              namedVariables: /\d+/,
              result: "3"
            }
          },
          {
            seq: 24,
            command: "scopes",
            arguments: {
              frameId: 3
            },
            type: "request"
          },
          {
            seq: 28,
            type: "response",
            command: "scopes",
            request_seq: 24,
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
                  variablesReference: 23
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
            seq: 25,
            command: "variables",
            arguments: {
              variablesReference: 23
            },
            type: "request"
          },
          {
            seq: 29,
            type: "response",
            command: "variables",
            request_seq: 25,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "%self",
                  value: "main",
                  type: "Object",
                  variablesReference: 24,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "a",
                  value: "3",
                  type: "Integer",
                  variablesReference: 25,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "d",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 26,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "e",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 27,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "f",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 28,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 26,
            command: "next",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 30,
            type: "response",
            command: "next",
            request_seq: 26,
            success: true,
            message: "Success"
          },
          {
            seq: 31,
            type: "event",
            event: "stopped",
            body: {
              reason: "step",
              threadId: 1,
              allThreadsStopped: true
            }
          },
          {
            seq: 27,
            command: "threads",
            type: "request"
          },
          {
            seq: 32,
            type: "response",
            command: "threads",
            request_seq: 27,
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
            seq: 28,
            command: "stackTrace",
            arguments: {
              threadId: 1,
              startFrame: 0,
              levels: 20
            },
            type: "request"
          },
          {
            seq: 33,
            type: "response",
            command: "stackTrace",
            request_seq: 28,
            success: true,
            message: "Success",
            body: {
              stackFrames: [
                {
                  name: "<main>",
                  line: 4,
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
            seq: 29,
            command: "evaluate",
            arguments: {
              expression: "a",
              frameId: 4,
              context: "watch"
            },
            type: "request"
          },
          {
            seq: 34,
            type: "response",
            command: "evaluate",
            request_seq: 29,
            success: true,
            message: "Success",
            body: {
              type: "Integer",
              variablesReference: 29,
              indexedVariables: 0,
              namedVariables: /\d+/,
              result: "4"
            }
          },
          {
            seq: 30,
            command: "scopes",
            arguments: {
              frameId: 4
            },
            type: "request"
          },
          {
            seq: 35,
            type: "response",
            command: "scopes",
            request_seq: 30,
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
                  variablesReference: 30
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
            seq: 31,
            command: "variables",
            arguments: {
              variablesReference: 30
            },
            type: "request"
          },
          {
            seq: 36,
            type: "response",
            command: "variables",
            request_seq: 31,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "%self",
                  value: "main",
                  type: "Object",
                  variablesReference: 31,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "a",
                  value: "4",
                  type: "Integer",
                  variablesReference: 32,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "d",
                  value: "nil",
                  type: "NilClass",
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
            seq: 32,
            command: "next",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 37,
            type: "response",
            command: "next",
            request_seq: 32,
            success: true,
            message: "Success"
          },
          {
            seq: 38,
            type: "event",
            event: "stopped",
            body: {
              reason: "step",
              threadId: 1,
              allThreadsStopped: true
            }
          },
          {
            seq: 33,
            command: "threads",
            type: "request"
          },
          {
            seq: 39,
            type: "response",
            command: "threads",
            request_seq: 33,
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
            seq: 34,
            command: "stackTrace",
            arguments: {
              threadId: 1,
              startFrame: 0,
              levels: 20
            },
            type: "request"
          },
          {
            seq: 40,
            type: "response",
            command: "stackTrace",
            request_seq: 34,
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
                    sourceReference: 0
                  },
                  id: 5
                }
              ]
            }
          },
          {
            seq: 35,
            command: "evaluate",
            arguments: {
              expression: "a",
              frameId: 5,
              context: "watch"
            },
            type: "request"
          },
          {
            seq: 41,
            type: "response",
            command: "evaluate",
            request_seq: 35,
            success: true,
            message: "Success",
            body: {
              type: "Integer",
              variablesReference: 36,
              indexedVariables: 0,
              namedVariables: /\d+/,
              result: "4"
            }
          },
          {
            seq: 36,
            command: "scopes",
            arguments: {
              frameId: 5
            },
            type: "request"
          },
          {
            seq: 42,
            type: "response",
            command: "scopes",
            request_seq: 36,
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
            seq: 37,
            command: "variables",
            arguments: {
              variablesReference: 37
            },
            type: "request"
          },
          {
            seq: 43,
            type: "response",
            command: "variables",
            request_seq: 37,
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
                  value: "4",
                  type: "Integer",
                  variablesReference: 39,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "d",
                  value: "4",
                  type: "Integer",
                  variablesReference: 40,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "e",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 41,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "f",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 42,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 38,
            command: "next",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 44,
            type: "response",
            command: "next",
            request_seq: 38,
            success: true,
            message: "Success"
          },
          {
            seq: 45,
            type: "event",
            event: "stopped",
            body: {
              reason: "step",
              threadId: 1,
              allThreadsStopped: true
            }
          },
          {
            seq: 39,
            command: "threads",
            type: "request"
          },
          {
            seq: 46,
            type: "response",
            command: "threads",
            request_seq: 39,
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
            seq: 40,
            command: "stackTrace",
            arguments: {
              threadId: 1,
              startFrame: 0,
              levels: 20
            },
            type: "request"
          },
          {
            seq: 47,
            type: "response",
            command: "stackTrace",
            request_seq: 40,
            success: true,
            message: "Success",
            body: {
              stackFrames: [
                {
                  name: "<main>",
                  line: 6,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: 0
                  },
                  id: 6
                }
              ]
            }
          },
          {
            seq: 41,
            command: "evaluate",
            arguments: {
              expression: "a",
              frameId: 6,
              context: "watch"
            },
            type: "request"
          },
          {
            seq: 48,
            type: "response",
            command: "evaluate",
            request_seq: 41,
            success: true,
            message: "Success",
            body: {
              type: "Integer",
              variablesReference: 43,
              indexedVariables: 0,
              namedVariables: /\d+/,
              result: "5"
            }
          },
          {
            seq: 42,
            command: "scopes",
            arguments: {
              frameId: 6
            },
            type: "request"
          },
          {
            seq: 49,
            type: "response",
            command: "scopes",
            request_seq: 42,
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
                  variablesReference: 44
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
            seq: 43,
            command: "variables",
            arguments: {
              variablesReference: 44
            },
            type: "request"
          },
          {
            seq: 50,
            type: "response",
            command: "variables",
            request_seq: 43,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "%self",
                  value: "main",
                  type: "Object",
                  variablesReference: 45,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "a",
                  value: "5",
                  type: "Integer",
                  variablesReference: 46,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "d",
                  value: "4",
                  type: "Integer",
                  variablesReference: 47,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "e",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 48,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "f",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 49,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 44,
            command: "continue",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 51,
            type: "response",
            command: "continue",
            request_seq: 44,
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

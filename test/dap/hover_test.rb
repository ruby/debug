# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  
  class HoverTest1638791703 < TestCase
    PROGRAM = <<~RUBY
      1| a = 1
      2| b = 2
      3| c = 3
      4| d = 4
      5| e = 5
    RUBY
    
    def test_hover_works_correctly
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
                4
              ],
              breakpoints: [
                {
                  line: 4
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
                  line: 4,
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
            seq: 16,
            command: "variables",
            arguments: {
              variablesReference: 9
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
                  variablesReference: 10,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "a",
                  value: "1",
                  type: "Integer",
                  variablesReference: 11,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "b",
                  value: "2",
                  type: "Integer",
                  variablesReference: 12,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "c",
                  value: "3",
                  type: "Integer",
                  variablesReference: 13,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "d",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 14,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "e",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 15,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 17,
            command: "evaluate",
            arguments: {
              expression: "b",
              frameId: 2,
              context: "hover"
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
              variablesReference: 16,
              indexedVariables: 0,
              namedVariables: /\d+/,
              result: "2"
            }
          },
          {
            seq: 18,
            command: "variables",
            arguments: {
              variablesReference: 16
            },
            type: "request"
          },
          {
            seq: 21,
            type: "response",
            command: "variables",
            request_seq: 18,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "#class",
                  value: "Integer",
                  type: "Class",
                  variablesReference: 17,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 19,
            command: "variables",
            arguments: {
              variablesReference: 17
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
                  name: "#class",
                  value: "Class",
                  type: "Class",
                  variablesReference: 18,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "%ancestors",
                  value: /JSON::Ext::Generator::GeneratorMethods::Integer/,
                  type: "Array",
                  variablesReference: 19,
                  indexedVariables: 10,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 20,
            command: "variables",
            arguments: {
              variablesReference: 18
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
                  name: "#class",
                  value: "Class",
                  type: "Class",
                  variablesReference: 20,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "%ancestors",
                  value: /Module/,
                  type: "Array",
                  variablesReference: 21,
                  indexedVariables: 8,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 21,
            command: "variables",
            arguments: {
              variablesReference: 19,
              filter: "indexed",
              start: 0,
              count: 10
            },
            type: "request"
          },
          {
            seq: 24,
            type: "response",
            command: "variables",
            request_seq: 21,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "0",
                  value: /.*/,
                  type: /.*/,
                  variablesReference: 22,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "1",
                  value: /.*/,
                  type: /.*/,
                  variablesReference: 23,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "2",
                  value: /.*/,
                  type: /.*/,
                  variablesReference: 24,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "3",
                  value: /.*/,
                  type: /.*/,
                  variablesReference: 25,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "4",
                  value: /.*/,
                  type: /.*/,
                  variablesReference: 26,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "5",
                  value: /.*/,
                  type: /.*/,
                  variablesReference: 27,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "6",
                  value: /.*/,
                  type: /.*/,
                  variablesReference: 28,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "7",
                  value: /.*/,
                  type: /.*/,
                  variablesReference: 29,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "8",
                  value: /.*/,
                  type: /.*/,
                  variablesReference: 30,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "9",
                  value: /.*/,
                  type: /.*/,
                  variablesReference: 31,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 22,
            command: "evaluate",
            arguments: {
              expression: "c",
              frameId: 2,
              context: "hover"
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
              variablesReference: 32,
              indexedVariables: 0,
              namedVariables: /\d+/,
              result: "3"
            }
          },
          {
            seq: 23,
            command: "variables",
            arguments: {
              variablesReference: 32
            },
            type: "request"
          },
          {
            seq: 26,
            type: "response",
            command: "variables",
            request_seq: 23,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "#class",
                  value: "Integer",
                  type: "Class",
                  variablesReference: 33,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 24,
            command: "evaluate",
            arguments: {
              expression: "b",
              frameId: 2,
              context: "hover"
            },
            type: "request"
          },
          {
            seq: 27,
            type: "response",
            command: "evaluate",
            request_seq: 24,
            success: true,
            message: "Success",
            body: {
              type: "Integer",
              variablesReference: 34,
              indexedVariables: 0,
              namedVariables: /\d+/,
              result: "2"
            }
          },
          {
            seq: 25,
            command: "variables",
            arguments: {
              variablesReference: 34
            },
            type: "request"
          },
          {
            seq: 28,
            type: "response",
            command: "variables",
            request_seq: 25,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "#class",
                  value: "Integer",
                  type: "Class",
                  variablesReference: 35,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 26,
            command: "evaluate",
            arguments: {
              expression: "a",
              frameId: 2,
              context: "hover"
            },
            type: "request"
          },
          {
            seq: 29,
            type: "response",
            command: "evaluate",
            request_seq: 26,
            success: true,
            message: "Success",
            body: {
              type: "Integer",
              variablesReference: 36,
              indexedVariables: 0,
              namedVariables: /\d+/,
              result: "1"
            }
          },
          {
            seq: 27,
            command: "variables",
            arguments: {
              variablesReference: 36
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
                  name: "#class",
                  value: "Integer",
                  type: "Class",
                  variablesReference: 37,
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

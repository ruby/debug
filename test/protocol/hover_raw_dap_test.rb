# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__

  class HoverTest1638791703 < ProtocolTestCase
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
                },
                {
                  name: "a",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 4,
                  namedVariables: /\d+/
                },
                {
                  name: "b",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 5,
                  namedVariables: /\d+/
                },
                {
                  name: "c",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 6,
                  namedVariables: /\d+/
                },
                {
                  name: "d",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 7,
                  namedVariables: /\d+/
                },
                {
                  name: "e",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 8,
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
                    sourceReference: 0
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
                  expensive: false,
                  variablesReference: 9
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
                  namedVariables: /\d+/
                },
                {
                  name: "a",
                  value: "1",
                  type: "Integer",
                  variablesReference: 11,
                  namedVariables: /\d+/
                },
                {
                  name: "b",
                  value: "2",
                  type: "Integer",
                  variablesReference: 12,
                  namedVariables: /\d+/
                },
                {
                  name: "c",
                  value: "3",
                  type: "Integer",
                  variablesReference: 13,
                  namedVariables: /\d+/
                },
                {
                  name: "d",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 14,
                  namedVariables: /\d+/
                },
                {
                  name: "e",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 15,
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
                  namedVariables: /\d+/
                },
                {
                  name: "%ancestors",
                  value: /JSON::Ext::Generator::GeneratorMethods::Integer/,
                  type: "Array",
                  variablesReference: 19,
                  indexedVariables: /(9|10)/,
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
                  namedVariables: /\d+/
                },
                {
                  name: "%ancestors",
                  value: /Module/,
                  type: "Array",
                  variablesReference: 21,
                  indexedVariables: /(7|8)/,
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
                  value: "JSON::Ext::Generator::GeneratorMethods::Integer",
                  type: "Module",
                  variablesReference: 22,
                  namedVariables: /\d+/
                },
                {
                  name: "1",
                  value: "Numeric",
                  type: "Class",
                  variablesReference: 23,
                  namedVariables: /\d+/
                },
                {
                  name: "2",
                  value: "Comparable",
                  type: "Module",
                  variablesReference: 24,
                  namedVariables: /\d+/
                },
                {
                  name: "3",
                  value: "Object",
                  type: "Class",
                  variablesReference: 25,
                  namedVariables: /\d+/
                },
                {
                  name: "4",
                  value: "JSON::Ext::Generator::GeneratorMethods::Object",
                  type: "Module",
                  variablesReference: 26,
                  namedVariables: /\d+/
                },
                {
                  name: "5",
                  value: "PP::ObjectMixin",
                  type: "Module",
                  variablesReference: 27,
                  namedVariables: /\d+/
                },
                {
                  name: "6",
                  value: "DEBUGGER__::TrapInterceptor",
                  type: "Module",
                  variablesReference: 28,
                  namedVariables: /\d+/
                },
                {
                  name: "7",
                  value: "Kernel",
                  type: "Module",
                  variablesReference: 29,
                  namedVariables: /\d+/
                },
                {
                  name: "8",
                  value: "BasicObject",
                  type: "Class",
                  variablesReference: 30,
                  namedVariables: /\d+/
                },
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
              variablesReference: 31,
              namedVariables: /\d+/,
              result: "3"
            }
          },
          {
            seq: 23,
            command: "variables",
            arguments: {
              variablesReference: 31
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
                  variablesReference: 32,
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
              variablesReference: 33,
              namedVariables: /\d+/,
              result: "2"
            }
          },
          {
            seq: 25,
            command: "variables",
            arguments: {
              variablesReference: 33
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
                  variablesReference: 34,
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
              variablesReference: 35,
              namedVariables: /\d+/,
              result: "1"
            }
          },
          {
            seq: 27,
            command: "variables",
            arguments: {
              variablesReference: 35
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
                  variablesReference: 36,
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
  class HoverTest1641198331 < ProtocolTestCase
    PROGRAM = <<~RUBY
       1| module Abc
       2|   class Def123
       3|     class Ghi
       4|       def initialize
       5|         @a = 1
       6|       end
       7|
       8|       def a
       9|         ::Abc.foo
      10|         ::Abc::Def123.bar
      11|         p @a
      12|       end
      13|     end
      14|
      15|     def bar
      16|       p :bar1
      17|     end
      18|
      19|     def self.bar
      20|       p :bar2
      21|     end
      22|   end
      23|
      24|   def self.foo
      25|     p :foo
      26|   end
      27| end
      28|
      29| Abc::Def123.new.bar
      30|
      31| ghi = Abc::Def123::Ghi.new
      32| ghi.a
    RUBY

    def test_1641198331
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
                },
                {
                  name: "ghi",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 4,
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
                29
              ],
              breakpoints: [
                {
                  line: 29
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
                  line: 29,
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
                  expensive: false,
                  variablesReference: 5
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
            seq: 16,
            command: "variables",
            arguments: {
              variablesReference: 5
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
                  variablesReference: 6,
                  namedVariables: /\d+/
                },
                {
                  name: "ghi",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 7,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 17,
            command: "evaluate",
            arguments: {
              expression: "Abc",
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
              type: "Module",
              variablesReference: 8,
              namedVariables: /\d+/,
              result: "Abc"
            }
          },
          {
            seq: 18,
            command: "variables",
            arguments: {
              variablesReference: 8
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
                  value: "Module",
                  type: "Class",
                  variablesReference: 9,
                  namedVariables: /\d+/
                },
                {
                  name: "%ancestors",
                  value: "[]",
                  type: "Array",
                  variablesReference: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 19,
            command: "evaluate",
            arguments: {
              expression: "Abc::Def123",
              frameId: 2,
              context: "hover"
            },
            type: "request"
          },
          {
            seq: 22,
            type: "response",
            command: "evaluate",
            request_seq: 19,
            success: true,
            message: "Success",
            body: {
              type: "Class",
              variablesReference: 10,
              namedVariables: /\d+/,
              result: "Abc::Def123"
            }
          },
          {
            seq: 20,
            command: "variables",
            arguments: {
              variablesReference: 10
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
                  variablesReference: 11,
                  namedVariables: /\d+/
                },
                {
                  name: "%ancestors",
                  value: /Object/,
                  type: "Array",
                  variablesReference: 12,
                  indexedVariables: /(6|7)/,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 21,
            command: "evaluate",
            arguments: {
              expression: "Abc",
              frameId: 2,
              context: "hover"
            },
            type: "request"
          },
          {
            seq: 24,
            type: "response",
            command: "evaluate",
            request_seq: 21,
            success: true,
            message: "Success",
            body: {
              type: "Module",
              variablesReference: 13,
              namedVariables: /\d+/,
              result: "Abc"
            }
          },
          {
            seq: 22,
            command: "variables",
            arguments: {
              variablesReference: 13
            },
            type: "request"
          },
          {
            seq: 25,
            type: "response",
            command: "variables",
            request_seq: 22,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "#class",
                  value: "Module",
                  type: "Class",
                  variablesReference: 14,
                  namedVariables: /\d+/
                },
                {
                  name: "%ancestors",
                  value: "[]",
                  type: "Array",
                  variablesReference: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 23,
            command: "evaluate",
            arguments: {
              expression: "Abc::Def123",
              frameId: 2,
              context: "hover"
            },
            type: "request"
          },
          {
            seq: 26,
            type: "response",
            command: "evaluate",
            request_seq: 23,
            success: true,
            message: "Success",
            body: {
              type: "Class",
              variablesReference: 15,
              namedVariables: /\d+/,
              result: "Abc::Def123"
            }
          },
          {
            seq: 24,
            command: "variables",
            arguments: {
              variablesReference: 15
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
                  name: "#class",
                  value: "Class",
                  type: "Class",
                  variablesReference: 16,
                  namedVariables: /\d+/
                },
                {
                  name: "%ancestors",
                  value: /Object/,
                  type: "Array",
                  variablesReference: 17,
                  indexedVariables: /(6|7)/,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 25,
            command: "evaluate",
            arguments: {
              expression: "Abc::Def123::Ghi",
              frameId: 2,
              context: "hover"
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
              type: "Class",
              variablesReference: 18,
              namedVariables: /\d+/,
              result: "Abc::Def123::Ghi"
            }
          },
          {
            seq: 26,
            command: "variables",
            arguments: {
              variablesReference: 18
            },
            type: "request"
          },
          {
            seq: 29,
            type: "response",
            command: "variables",
            request_seq: 26,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "#class",
                  value: "Class",
                  type: "Class",
                  variablesReference: 19,
                  namedVariables: /\d+/
                },
                {
                  name: "%ancestors",
                  value: /Object/,
                  type: "Array",
                  variablesReference: 20,
                  indexedVariables: /(6|7)/,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 27,
            command: "evaluate",
            arguments: {
              expression: "Abc::Def123::Ghi.new",
              frameId: 2,
              context: "hover"
            },
            type: "request"
          },
          {
            seq: 30,
            type: "response",
            command: "evaluate",
            request_seq: 27,
            success: true,
            message: "Success",
            body: {
              type: "Class",
              variablesReference: 21,
              namedVariables: /\d+/,
              result: "Abc::Def123::Ghi"
            }
          },
          {
            seq: 28,
            command: "variables",
            arguments: {
              variablesReference: 21
            },
            type: "request"
          },
          {
            seq: 31,
            type: "response",
            command: "variables",
            request_seq: 28,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "#class",
                  value: "Class",
                  type: "Class",
                  variablesReference: 22,
                  namedVariables: /\d+/
                },
                {
                  name: "%ancestors",
                  value: /Object/,
                  type: "Array",
                  variablesReference: 23,
                  indexedVariables: /(6|7)/,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 29,
            command: "evaluate",
            arguments: {
              expression: "::Abc.foo",
              frameId: 2,
              context: "hover"
            },
            type: "request"
          },
          {
            seq: 32,
            type: "response",
            command: "evaluate",
            request_seq: 29,
            success: true,
            message: "Success",
            body: {
              type: "Module",
              variablesReference: 24,
              namedVariables: /\d+/,
              result: "Abc"
            }
          },
          {
            seq: 30,
            command: "variables",
            arguments: {
              variablesReference: 24
            },
            type: "request"
          },
          {
            seq: 33,
            type: "response",
            command: "variables",
            request_seq: 30,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "#class",
                  value: "Module",
                  type: "Class",
                  variablesReference: 25,
                  namedVariables: /\d+/
                },
                {
                  name: "%ancestors",
                  value: "[]",
                  type: "Array",
                  variablesReference: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 31,
            command: "evaluate",
            arguments: {
              expression: "::Abc::Def123.bar",
              frameId: 2,
              context: "hover"
            },
            type: "request"
          },
          {
            seq: 34,
            type: "response",
            command: "evaluate",
            request_seq: 31,
            success: true,
            message: "Success",
            body: {
              type: "Class",
              variablesReference: 26,
              namedVariables: /\d+/,
              result: "Abc::Def123"
            }
          },
          {
            seq: 32,
            command: "variables",
            arguments: {
              variablesReference: 26
            },
            type: "request"
          },
          {
            seq: 35,
            type: "response",
            command: "variables",
            request_seq: 32,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "#class",
                  value: "Class",
                  type: "Class",
                  variablesReference: 27,
                  namedVariables: /\d+/
                },
                {
                  name: "%ancestors",
                  value: /Object/,
                  type: "Array",
                  variablesReference: 28,
                  indexedVariables: /(6|7)/,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 33,
            command: "evaluate",
            arguments: {
              expression: "::Abc::Def123",
              frameId: 2,
              context: "hover"
            },
            type: "request"
          },
          {
            seq: 36,
            type: "response",
            command: "evaluate",
            request_seq: 33,
            success: true,
            message: "Success",
            body: {
              type: "Class",
              variablesReference: 29,
              namedVariables: /\d+/,
              result: "Abc::Def123"
            }
          },
          {
            seq: 34,
            command: "variables",
            arguments: {
              variablesReference: 29
            },
            type: "request"
          },
          {
            seq: 37,
            type: "response",
            command: "variables",
            request_seq: 34,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "#class",
                  value: "Class",
                  type: "Class",
                  variablesReference: 30,
                  namedVariables: /\d+/
                },
                {
                  name: "%ancestors",
                  value: /Object/,
                  type: "Array",
                  variablesReference: 31,
                  indexedVariables: /(6|7)/,
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
            seq: 38,
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

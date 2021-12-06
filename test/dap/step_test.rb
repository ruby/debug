# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  
  class StepTest1638676609 < TestCase
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
    
    def test_step_works_correctly
      run_dap_scenario PROGRAM do
        [
          *CFG_DAP,
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
                }
              ]
            }
          },
          {
            seq: 11,
            command: "stepIn",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 13,
            type: "response",
            command: "stepIn",
            request_seq: 11,
            success: true,
            message: "Success"
          },
          {
            seq: 14,
            type: "event",
            event: "stopped",
            body: {
              reason: "step",
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
                  name: "<module:Foo>",
                  line: 2,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: nil
                  },
                  id: 2
                },
                {
                  name: "<main>",
                  line: 1,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: nil
                  },
                  id: 3
                }
              ]
            }
          },
          {
            seq: 14,
            command: "stepIn",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 17,
            type: "response",
            command: "stepIn",
            request_seq: 14,
            success: true,
            message: "Success"
          },
          {
            seq: 18,
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
                  name: "<class:Bar>",
                  line: 3,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: nil
                  },
                  id: 4
                },
                {
                  name: "<module:Foo>",
                  line: 2,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: nil
                  },
                  id: 5
                },
                {
                  name: "<main>",
                  line: 1,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: nil
                  },
                  id: 6
                }
              ]
            }
          },
          {
            seq: 17,
            command: "stepIn",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 21,
            type: "response",
            command: "stepIn",
            request_seq: 17,
            success: true,
            message: "Success"
          },
          {
            seq: 22,
            type: "event",
            event: "stopped",
            body: {
              reason: "step",
              threadId: 1,
              allThreadsStopped: true
            }
          },
          {
            seq: 18,
            command: "threads",
            type: "request"
          },
          {
            seq: 23,
            type: "response",
            command: "threads",
            request_seq: 18,
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
            seq: 19,
            command: "stackTrace",
            arguments: {
              threadId: 1,
              startFrame: 0,
              levels: 20
            },
            type: "request"
          },
          {
            seq: 24,
            type: "response",
            command: "stackTrace",
            request_seq: 19,
            success: true,
            message: "Success",
            body: {
              stackFrames: [
                {
                  name: "<module:Foo>",
                  line: 7,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: nil
                  },
                  id: 7
                },
                {
                  name: "<main>",
                  line: 1,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: nil
                  },
                  id: 8
                }
              ]
            }
          },
          {
            seq: 20,
            command: "stepIn",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 25,
            type: "response",
            command: "stepIn",
            request_seq: 20,
            success: true,
            message: "Success"
          },
          {
            seq: 26,
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
            seq: 27,
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
            seq: 28,
            type: "response",
            command: "stackTrace",
            request_seq: 22,
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
                    sourceReference: nil
                  },
                  id: 9
                },
                {
                  name: "<module:Foo>",
                  line: 7,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: nil
                  },
                  id: 10
                },
                {
                  name: "<main>",
                  line: 1,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: nil
                  },
                  id: 11
                }
              ]
            }
          },
          {
            seq: 23,
            command: "stepIn",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 29,
            type: "response",
            command: "stepIn",
            request_seq: 23,
            success: true,
            message: "Success"
          },
          {
            seq: 30,
            type: "event",
            event: "stopped",
            body: {
              reason: "step",
              threadId: 1,
              allThreadsStopped: true
            }
          },
          {
            seq: 24,
            command: "threads",
            type: "request"
          },
          {
            seq: 31,
            type: "response",
            command: "threads",
            request_seq: 24,
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
            seq: 25,
            command: "stackTrace",
            arguments: {
              threadId: 1,
              startFrame: 0,
              levels: 20
            },
            type: "request"
          },
          {
            seq: 32,
            type: "response",
            command: "stackTrace",
            request_seq: 25,
            success: true,
            message: "Success",
            body: {
              stackFrames: [
                {
                  name: "Foo::Bar.a",
                  line: 5,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: nil
                  },
                  id: 12
                },
                {
                  name: "<module:Foo>",
                  line: 7,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: nil
                  },
                  id: 13
                },
                {
                  name: "<main>",
                  line: 1,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: nil
                  },
                  id: 14
                }
              ]
            }
          },
          {
            seq: 26,
            command: "stepIn",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 33,
            type: "response",
            command: "stepIn",
            request_seq: 26,
            success: true,
            message: "Success"
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
            seq: 27,
            command: "scopes",
            arguments: {
              frameId: 12
            },
            type: "request"
          },
          {
            seq: 35,
            type: "response",
            command: "scopes",
            request_seq: 27,
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
            seq: 28,
            command: "threads",
            type: "request"
          },
          {
            seq: 36,
            type: "response",
            command: "threads",
            request_seq: 28,
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
            seq: 29,
            command: "variables",
            arguments: {
              variablesReference: 4
            },
            type: "request"
          },
          {
            seq: 37,
            type: "response",
            command: "variables",
            request_seq: 29,
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
                  name: "bar",
                  value: "nil",
                  type: "NilClass",
                  variablesReference: 6,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 30,
            command: "stackTrace",
            arguments: {
              threadId: 1,
              startFrame: 0,
              levels: 20
            },
            type: "request"
          },
          {
            seq: 38,
            type: "response",
            command: "stackTrace",
            request_seq: 30,
            success: true,
            message: "Success",
            body: {
              stackFrames: [
                {
                  name: "<module:Foo>",
                  line: 8,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: nil
                  },
                  id: 15
                },
                {
                  name: "<main>",
                  line: 1,
                  column: 1,
                  source: {
                    name: /#{File.basename temp_file_path}/,
                    path: /#{temp_file_path}/,
                    sourceReference: nil
                  },
                  id: 16
                }
              ]
            }
          },
          {
            seq: 31,
            command: "scopes",
            arguments: {
              frameId: 15
            },
            type: "request"
          },
          {
            seq: 39,
            type: "response",
            command: "scopes",
            request_seq: 31,
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
                  variablesReference: 7
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
            seq: 32,
            command: "variables",
            arguments: {
              variablesReference: 7
            },
            type: "request"
          },
          {
            seq: 40,
            type: "response",
            command: "variables",
            request_seq: 32,
            success: true,
            message: "Success",
            body: {
              variables: [
                {
                  name: "%self",
                  value: "Foo",
                  type: "Module",
                  variablesReference: 8,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "bar",
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
            seq: 33,
            command: "stepIn",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 41,
            type: "response",
            command: "stepIn",
            request_seq: 33,
            success: true,
            message: "Success"
          }
        ]
      end
    end
  end
end

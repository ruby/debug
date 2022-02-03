# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class DeleteTest1643896612 < TestCase
    PROGRAM = <<~RUBY
      1| a = 1
      2| a += 1
      3| b = 2
      4| a += 1
      5| c = 2
      6| a += 1
      7| a += 1
    RUBY
    
    def test_delete_deletes_all_breakpoints_1643896612
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
                3
              ],
              breakpoints: [
                {
                  line: 3
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
            command: "setBreakpoints",
            arguments: {
              source: {
                name: "target.rb",
                path: temp_file_path,
                sourceReference: nil
              },
              lines: [
                3,
                5
              ],
              breakpoints: [
                {
                  line: 3
                },
                {
                  line: 5
                }
              ],
              sourceModified: false
            },
            type: "request"
          },
          {
            seq: 14,
            type: "response",
            command: "setBreakpoints",
            request_seq: 12,
            success: true,
            message: "Success",
            body: {
              breakpoints: [
                {
                  verified: true
                },
                {
                  verified: true
                }
              ]
            }
          },
          {
            seq: 13,
            command: "setBreakpoints",
            arguments: {
              source: {
                name: "target.rb",
                path: temp_file_path,
                sourceReference: nil
              },
              lines: [
                3,
                5,
                7
              ],
              breakpoints: [
                {
                  line: 3
                },
                {
                  line: 5
                },
                {
                  line: 7
                }
              ],
              sourceModified: false
            },
            type: "request"
          },
          {
            seq: 15,
            type: "response",
            command: "setBreakpoints",
            request_seq: 13,
            success: true,
            message: "Success",
            body: {
              breakpoints: [
                {
                  verified: true
                },
                {
                  verified: true
                },
                {
                  verified: true
                }
              ]
            }
          },
          {
            seq: 14,
            command: "setBreakpoints",
            arguments: {
              source: {
                name: "target.rb",
                path: temp_file_path,
                sourceReference: nil
              },
              lines: [
                3,
                7
              ],
              breakpoints: [
                {
                  line: 3
                },
                {
                  line: 7
                }
              ],
              sourceModified: false
            },
            type: "request"
          },
          {
            seq: 16,
            type: "response",
            command: "setBreakpoints",
            request_seq: 14,
            success: true,
            message: "Success",
            body: {
              breakpoints: [
                {
                  verified: true
                },
                {
                  verified: true
                }
              ]
            }
          },
          {
            seq: 15,
            command: "setBreakpoints",
            arguments: {
              source: {
                name: "target.rb",
                path: temp_file_path,
                sourceReference: nil
              },
              lines: [
                7
              ],
              breakpoints: [
                {
                  line: 7
                }
              ],
              sourceModified: false
            },
            type: "request"
          },
          {
            seq: 17,
            type: "response",
            command: "setBreakpoints",
            request_seq: 15,
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
            seq: 16,
            command: "setBreakpoints",
            arguments: {
              source: {
                name: "target.rb",
                path: temp_file_path,
                sourceReference: nil
              },
              lines: [
          
              ],
              breakpoints: [
          
              ],
              sourceModified: false
            },
            type: "request"
          },
          {
            seq: 18,
            type: "response",
            command: "setBreakpoints",
            request_seq: 16,
            success: true,
            message: "Success",
            body: {
              breakpoints: [
          
              ]
            }
          },
          {
            seq: 17,
            command: "evaluate",
            arguments: {
              expression: "a",
              frameId: 1,
              context: "hover"
            },
            type: "request"
          },
          {
            seq: 19,
            type: "response",
            command: "evaluate",
            request_seq: 17,
            success: true,
            message: "Success",
            body: {
              type: "NilClass",
              variablesReference: 7,
              indexedVariables: 0,
              namedVariables: /\d+/,
              result: "nil"
            }
          },
          {
            seq: 18,
            command: "variables",
            arguments: {
              variablesReference: 7
            },
            type: "request"
          },
          {
            seq: 20,
            type: "response",
            command: "variables",
            request_seq: 18,
            success: true,
            message: "Success",
            body: {
              variables: [
          
              ]
            }
          },
          {
            seq: 19,
            command: "continue",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 21,
            type: "response",
            command: "continue",
            request_seq: 19,
            success: true,
            message: "Success",
            body: {
              allThreadsContinued: true
            }
          }
        ]
      end
    end

    def test_delete_deletes_specific_breakpoint
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
                3
              ],
              breakpoints: [
                {
                  line: 3
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
            command: "setBreakpoints",
            arguments: {
              source: {
                name: "target.rb",
                path: temp_file_path,
                sourceReference: nil
              },
              lines: [
                3,
                6
              ],
              breakpoints: [
                {
                  line: 3
                },
                {
                  line: 6
                }
              ],
              sourceModified: false
            },
            type: "request"
          },
          {
            seq: 14,
            type: "response",
            command: "setBreakpoints",
            request_seq: 12,
            success: true,
            message: "Success",
            body: {
              breakpoints: [
                {
                  verified: true
                },
                {
                  verified: true
                }
              ]
            }
          },
          {
            seq: 13,
            command: "setBreakpoints",
            arguments: {
              source: {
                name: "target.rb",
                path: temp_file_path,
                sourceReference: nil
              },
              lines: [
                6
              ],
              breakpoints: [
                {
                  line: 6
                }
              ],
              sourceModified: false
            },
            type: "request"
          },
          {
            seq: 15,
            type: "response",
            command: "setBreakpoints",
            request_seq: 13,
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
            seq: 14,
            command: "continue",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 16,
            type: "response",
            command: "continue",
            request_seq: 14,
            success: true,
            message: "Success",
            body: {
              allThreadsContinued: true
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
                  line: 6,
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
            seq: 17,
            command: "scopes",
            arguments: {
              frameId: 2
            },
            type: "request"
          },
          {
            seq: 20,
            type: "response",
            command: "scopes",
            request_seq: 17,
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
            seq: 18,
            command: "variables",
            arguments: {
              variablesReference: 7
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
                  name: "%self",
                  value: "main",
                  type: "Object",
                  variablesReference: 8,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "a",
                  value: "3",
                  type: "Integer",
                  variablesReference: 9,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "b",
                  value: "2",
                  type: "Integer",
                  variablesReference: 10,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                },
                {
                  name: "c",
                  value: "2",
                  type: "Integer",
                  variablesReference: 11,
                  indexedVariables: 0,
                  namedVariables: /\d+/
                }
              ]
            }
          },
          {
            seq: 19,
            command: "continue",
            arguments: {
              threadId: 1
            },
            type: "request"
          },
          {
            seq: 22,
            type: "response",
            command: "continue",
            request_seq: 19,
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

# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__

  class CatchTest1647168678 < ProtocolTestCase
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

    def test_1647168678
      run_cdp_scenario PROGRAM do
        [
          *INITIALIZE_CDP_MSGS,
          {
            method: "Debugger.scriptParsed",
            params: {
              scriptId: /.+/,
              url: /.+/,
              startLine: 0,
              startColumn: 0,
              endLine: 9,
              endColumn: 0,
              executionContextId: 1,
              hash: /.+/
            }
          },
          {
            method: "Debugger.paused",
            params: {
              reason: "other",
              callFrames: [
                {
                  callFrameId: /.+/,
                  functionName: "<main>",
                  functionLocation: {
                    lineNumber: 0,
                    scriptId: /.+/
                  },
                  location: {
                    lineNumber: 0,
                    scriptId: /.+/
                  },
                  url: /.+/,
                  scopeChain: [
                    {
                      type: "local",
                      object: {
                        type: "object",
                        objectId: /.+/
                      }
                    },
                    {
                      type: "script",
                      object: {
                        type: "object",
                        objectId: /.+/
                      }
                    },
                    {
                      type: "global",
                      object: {
                        type: "object",
                        objectId: /.+/
                      }
                    }
                  ],
                  this: {
                    type: "object"
                  }
                }
              ]
            }
          },
          {
            id: 8,
            method: "Debugger.getScriptSource",
            params: {
              scriptId: "1"
            }
          },
          {
            id: 8,
            result: {
              scriptSource: "module Foo\n  class Bar\n    def self.a\n      raise 'foo'\n    end\n  end\n  Bar.a\n  bar = Bar.new\nend"
            }
          },
          {
            id: 9,
            method: "Runtime.getProperties",
            params: {
              objectId: "0:local",
              ownProperties: false,
              accessorPropertiesOnly: false,
              nonIndexedPropertiesOnly: false,
              generatePreview: true
            }
          },
          {
            id: 9,
            result: {
              result: [
                {
                  name: "%self",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "Object"
                  },
                  configurable: true,
                  enumerable: true
                }
              ]
            }
          },
          {
            id: 10,
            method: "Runtime.getProperties",
            params: {
              objectId: "0:local",
              ownProperties: false,
              accessorPropertiesOnly: false,
              nonIndexedPropertiesOnly: false,
              generatePreview: true
            }
          },
          {
            id: 10,
            result: {
              result: [
                {
                  name: "%self",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "Object"
                  },
                  configurable: true,
                  enumerable: true
                }
              ]
            }
          },
          {
            id: 11,
            method: "Debugger.setPauseOnExceptions",
            params: {
              state: "uncaught"
            }
          },
          {
            id: 11,
            result: {
            }
          },
          {
            id: 12,
            method: "Debugger.setPauseOnExceptions",
            params: {
              state: "all"
            }
          },
          {
            id: 12,
            result: {
            }
          },
          {
            id: 13,
            method: "Debugger.resume",
            params: {
              terminateOnResume: false
            }
          },
          {
            id: 13,
            result: {
            }
          },
          {
            method: "Debugger.resumed",
            params: {
            }
          },
          {
            method: "Debugger.scriptParsed",
            params: {
              scriptId: /.+/,
              url: /.+/,
              startLine: 0,
              startColumn: 0,
              endLine: 9,
              endColumn: 0,
              executionContextId: 1,
              hash: /.+/
            }
          },
          {
            method: "Debugger.scriptParsed",
            params: {
              scriptId: /.+/,
              url: /.+/,
              startLine: 0,
              startColumn: 0,
              endLine: 9,
              endColumn: 0,
              executionContextId: 1,
              hash: /.+/
            }
          },
          {
            method: "Debugger.scriptParsed",
            params: {
              scriptId: /.+/,
              url: /.+/,
              startLine: 0,
              startColumn: 0,
              endLine: 9,
              endColumn: 0,
              executionContextId: 1,
              hash: /.+/
            }
          },
          {
            method: "Debugger.paused",
            params: {
              reason: "exception",
              callFrames: [
                {
                  callFrameId: /.+/,
                  functionName: "Foo::Bar.a",
                  functionLocation: {
                    lineNumber: 2,
                    scriptId: /.+/
                  },
                  location: {
                    lineNumber: 3,
                    scriptId: /.+/
                  },
                  url: /.+/,
                  scopeChain: [
                    {
                      type: "local",
                      object: {
                        type: "object",
                        objectId: /.+/
                      }
                    },
                    {
                      type: "script",
                      object: {
                        type: "object",
                        objectId: /.+/
                      }
                    },
                    {
                      type: "global",
                      object: {
                        type: "object",
                        objectId: /.+/
                      }
                    }
                  ],
                  this: {
                    type: "object"
                  }
                },
                {
                  callFrameId: /.+/,
                  functionName: "<module:Foo>",
                  functionLocation: {
                    lineNumber: 0,
                    scriptId: /.+/
                  },
                  location: {
                    lineNumber: 6,
                    scriptId: /.+/
                  },
                  url: /.+/,
                  scopeChain: [
                    {
                      type: "local",
                      object: {
                        type: "object",
                        objectId: /.+/
                      }
                    },
                    {
                      type: "script",
                      object: {
                        type: "object",
                        objectId: /.+/
                      }
                    },
                    {
                      type: "global",
                      object: {
                        type: "object",
                        objectId: /.+/
                      }
                    }
                  ],
                  this: {
                    type: "object"
                  }
                },
                {
                  callFrameId: /.+/,
                  functionName: "<main>",
                  functionLocation: {
                    lineNumber: 0,
                    scriptId: /.+/
                  },
                  location: {
                    lineNumber: 0,
                    scriptId: /.+/
                  },
                  url: /.+/,
                  scopeChain: [
                    {
                      type: "local",
                      object: {
                        type: "object",
                        objectId: /.+/
                      }
                    },
                    {
                      type: "script",
                      object: {
                        type: "object",
                        objectId: /.+/
                      }
                    },
                    {
                      type: "global",
                      object: {
                        type: "object",
                        objectId: /.+/
                      }
                    }
                  ],
                  this: {
                    type: "object"
                  }
                }
              ],
              data: {
                type: "object",
                description: /.+/,
                objectId: /.+/,
                subtype: "error",
                className: "RuntimeError"
              }
            }
          },
          {
            id: 14,
            method: "Runtime.getProperties",
            params: {
              objectId: "0:local",
              ownProperties: false,
              accessorPropertiesOnly: false,
              nonIndexedPropertiesOnly: false,
              generatePreview: true
            }
          },
          {
            id: 15,
            method: "Runtime.getProperties",
            params: {
              objectId: "0:local",
              ownProperties: false,
              accessorPropertiesOnly: false,
              nonIndexedPropertiesOnly: false,
              generatePreview: true
            }
          },
          {
            id: 14,
            result: {
              result: [
                {
                  name: "%self",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "Class"
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "_raised",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    subtype: "error",
                    className: "RuntimeError"
                  },
                  configurable: true,
                  enumerable: true
                }
              ]
            }
          },
          {
            id: 15,
            result: {
              result: [
                {
                  name: "%self",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "Class"
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "_raised",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    subtype: "error",
                    className: "RuntimeError"
                  },
                  configurable: true,
                  enumerable: true
                }
              ]
            }
          },
          {
            id: 16,
            method: "Debugger.resume",
            params: {
              terminateOnResume: false
            }
          },
          {
            id: 16,
            result: {
            }
          },
          {
            method: "Debugger.resumed",
            params: {
            }
          }
        ]
      end
    end
  end
end

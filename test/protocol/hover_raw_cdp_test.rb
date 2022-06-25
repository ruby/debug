# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__

  class HoverTest1647163915 < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| a = 1
      2| b = 2
      3| c = 3
      4| d = 4
      5| e = 5

    RUBY

    def test_1647163915
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
              endLine: 5,
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
              scriptSource: "a = 1\nb = 2\nc = 3\nd = 4\ne = 5\n"
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
                },
                {
                  name: "a",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "NilClass"
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "b",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "NilClass"
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "c",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "NilClass"
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "d",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "NilClass"
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "e",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "NilClass"
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
                },
                {
                  name: "a",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "NilClass"
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "b",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "NilClass"
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "c",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "NilClass"
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "d",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "NilClass"
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "e",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "NilClass"
                  },
                  configurable: true,
                  enumerable: true
                }
              ]
            }
          },
          {
            id: 11,
            method: "Debugger.getPossibleBreakpoints",
            params: {
              start: {
                scriptId: "1",
                lineNumber: 0,
                columnNumber: 0
              },
              restrictToFunction: true
            }
          },
          {
            id: 11,
            result: {
              locations: [
                {
                  scriptId: /.+/,
                  lineNumber: 0
                }
              ]
            }
          },
          {
            id: 12,
            method: "Debugger.setBreakpointsActive",
            params: {
              active: true
            }
          },
          {
            id: 12,
            result: {
            }
          },
          {
            id: 13,
            method: "Debugger.setBreakpointByUrl",
            params: {
              lineNumber: 3,
              urlRegex: "#{File.realpath(temp_file_path)}|file://#{File.realpath(temp_file_path)}",
              columnNumber: 0,
              condition: ""
            }
          },
          {
            id: 13,
            result: {
              breakpointId: /.+/,
              locations: [
                {
                  scriptId: /.+/,
                  lineNumber: 3
                }
              ]
            }
          },
          {
            id: 14,
            method: "Debugger.getPossibleBreakpoints",
            params: {
              start: {
                scriptId: "1",
                lineNumber: 3,
                columnNumber: 0
              },
              end: {
                scriptId: "1",
                lineNumber: 3,
                columnNumber: 5
              },
              restrictToFunction: false
            }
          },
          {
            id: 14,
            result: {
              locations: [
                {
                  scriptId: /.+/,
                  lineNumber: 3
                }
              ]
            }
          },
          {
            id: 15,
            method: "Debugger.resume",
            params: {
              terminateOnResume: false
            }
          },
          {
            id: 15,
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
              endLine: 5,
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
                }
              ]
            }
          },
          {
            id: 16,
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
            id: 17,
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
            id: 16,
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
                },
                {
                  name: "a",
                  value: {
                    type: "number",
                    description: /.+/,
                    value: 1,
                    objectId: /.+/
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "b",
                  value: {
                    type: "number",
                    description: /.+/,
                    value: 2,
                    objectId: /.+/
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "c",
                  value: {
                    type: "number",
                    description: /.+/,
                    value: 3,
                    objectId: /.+/
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "d",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "NilClass"
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "e",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "NilClass"
                  },
                  configurable: true,
                  enumerable: true
                }
              ]
            }
          },
          {
            id: 17,
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
                },
                {
                  name: "a",
                  value: {
                    type: "number",
                    description: /.+/,
                    value: 1,
                    objectId: /.+/
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "b",
                  value: {
                    type: "number",
                    description: /.+/,
                    value: 2,
                    objectId: /.+/
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "c",
                  value: {
                    type: "number",
                    description: /.+/,
                    value: 3,
                    objectId: /.+/
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "d",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "NilClass"
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "e",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "NilClass"
                  },
                  configurable: true,
                  enumerable: true
                }
              ]
            }
          },
          {
            id: 18,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "b0517caf9ad3aa17aec13bda2d6a7e41",
              expression: "c",
              objectGroup: "popover",
              includeCommandLineAPI: false,
              silent: true,
              returnByValue: false,
              generatePreview: false
            }
          },
          {
            method: "Debugger.scriptParsed",
            params: {
              scriptId: /.+/,
              url: "",
              startLine: 0,
              startColumn: 0,
              endLine: 1,
              endColumn: 0,
              executionContextId: 1,
              hash: /.+/
            }
          },
          {
            id: 18,
            result: {
              result: {
                type: "number",
                description: /.+/,
                value: 3,
                objectId: /.+/
              }
            }
          },
          {
            id: 19,
            method: "Runtime.releaseObjectGroup",
            params: {
              objectGroup: "popover"
            }
          },
          {
            id: 19,
            result: {
            }
          },
          {
            id: 20,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "b0517caf9ad3aa17aec13bda2d6a7e41",
              expression: "b",
              objectGroup: "popover",
              includeCommandLineAPI: false,
              silent: true,
              returnByValue: false,
              generatePreview: false
            }
          },
          {
            method: "Debugger.scriptParsed",
            params: {
              scriptId: /.+/,
              url: "",
              startLine: 0,
              startColumn: 0,
              endLine: 1,
              endColumn: 0,
              executionContextId: 1,
              hash: /.+/
            }
          },
          {
            id: 20,
            result: {
              result: {
                type: "number",
                description: /.+/,
                value: 2,
                objectId: /.+/
              }
            }
          },
          {
            id: 21,
            method: "Runtime.releaseObjectGroup",
            params: {
              objectGroup: "popover"
            }
          },
          {
            id: 21,
            result: {
            }
          },
          {
            id: 22,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "b0517caf9ad3aa17aec13bda2d6a7e41",
              expression: "a",
              objectGroup: "popover",
              includeCommandLineAPI: false,
              silent: true,
              returnByValue: false,
              generatePreview: false
            }
          },
          {
            method: "Debugger.scriptParsed",
            params: {
              scriptId: /.+/,
              url: "",
              startLine: 0,
              startColumn: 0,
              endLine: 1,
              endColumn: 0,
              executionContextId: 1,
              hash: /.+/
            }
          },
          {
            id: 22,
            result: {
              result: {
                type: "number",
                description: /.+/,
                value: 1,
                objectId: /.+/
              }
            }
          },
          {
            id: 23,
            method: "Runtime.releaseObjectGroup",
            params: {
              objectGroup: "popover"
            }
          },
          {
            id: 23,
            result: {
            }
          },
          {
            id: 24,
            method: "Debugger.resume",
            params: {
              terminateOnResume: false
            }
          },
          {
            id: 24,
            result: {
            }
          }
        ]
      end
    end
  end
end

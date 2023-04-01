# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__

  class HoverTest1680367110 < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| a = 1
      2| b = 2
      3| c = 3
      4| d = 4
      5| e = 5

    RUBY

    def test_1680367110
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
            method: "Debugger.setBreakpointsActive",
            params: {
              active: true
            }
          },
          {
            id: 10,
            result: {
            }
          },
          {
            id: 11,
            method: "Debugger.setBreakpointByUrl",
            params: {
              lineNumber: 3,
              urlRegex: "#{File.realpath(temp_file_path)}|file://#{File.realpath(temp_file_path)}",
              columnNumber: 0,
              condition: ""
            }
          },
          {
            id: 11,
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
            id: 12,
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
            id: 12,
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
            id: 14,
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
            id: 15,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "749f0545d098a59afc45091a1b8edc35",
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
            id: 15,
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
            id: 16,
            method: "Runtime.releaseObjectGroup",
            params: {
              objectGroup: "popover"
            }
          },
          {
            id: 16,
            result: {
            }
          },
          {
            id: 17,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "749f0545d098a59afc45091a1b8edc35",
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
            id: 17,
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
            id: 18,
            method: "Runtime.releaseObjectGroup",
            params: {
              objectGroup: "popover"
            }
          },
          {
            id: 18,
            result: {
            }
          },
          {
            id: 19,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "749f0545d098a59afc45091a1b8edc35",
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
            id: 19,
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
            id: 20,
            method: "Runtime.releaseObjectGroup",
            params: {
              objectGroup: "popover"
            }
          },
          {
            id: 20,
            result: {
            }
          },
          {
            id: 21,
            method: "Debugger.resume",
            params: {
              terminateOnResume: false
            }
          },
          {
            id: 21,
            result: {
            }
          }
        ]
      end
    end
  end
end

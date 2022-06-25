# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__
  class WatchTest1647161607 < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| a = 2
      2| a += 1
      3| a += 1
      4| d = 4
      5| a += 1
      6| e = 5
      7| f = 6
    RUBY

    def test_1647161607
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
              endLine: 7,
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
              scriptSource: "a = 2\na += 1\na += 1\nd = 4\na += 1\ne = 5\nf = 6"
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
                },
                {
                  name: "f",
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
                },
                {
                  name: "f",
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
            method: "Runtime.getProperties",
            params: {
              objectId: "0:script",
              ownProperties: false,
              accessorPropertiesOnly: false,
              nonIndexedPropertiesOnly: false,
              generatePreview: true
            }
          },
          {
            id: 12,
            method: "Runtime.getProperties",
            params: {
              objectId: "0:global",
              ownProperties: false,
              accessorPropertiesOnly: false,
              nonIndexedPropertiesOnly: false,
              generatePreview: false
            }
          },
          {
            id: 11,
            result: {
              result: [
          
              ]
            }
          },
          {
            id: 12,
            result: {
              result: [
          
              ]
            }
          },
          {
            id: 13,
            method: "Runtime.evaluate",
            params: {
              expression: "(async function(){ await 1; })()",
              contextId: "50d169823cddf0a4b6ce990dd7e51844",
              throwOnSideEffect: true
            }
          },
          {
            id: 14,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "0f91c69d774fa115d355aa58101be1e3",
              expression: "a",
              objectGroup: "watch-group",
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
            id: 14,
            result: {
              result: {
                type: "object",
                description: /.+/,
                objectId: /.+/,
                className: "NilClass"
              }
            }
          },
          {
            id: 15,
            method: "Debugger.stepOver",
            params: {
              skipList: [
          
              ]
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
              endLine: 7,
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
                    lineNumber: 1,
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
            method: "Runtime.evaluate",
            params: {
              expression: "a",
              objectGroup: "watch-group",
              includeCommandLineAPI: false,
              silent: true,
              returnByValue: false,
              generatePreview: false,
              userGesture: false,
              awaitPromise: false,
              contextId: "50d169823cddf0a4b6ce990dd7e51844"
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
            id: 18,
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
                    value: 2,
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
                },
                {
                  name: "f",
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
                    value: 2,
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
                },
                {
                  name: "f",
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
            id: 19,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "4214a828add392fa49b2b22782a4d3fd",
              expression: "a",
              objectGroup: "watch-group",
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
                value: 2,
                objectId: /.+/
              }
            }
          },
          {
            id: 20,
            method: "Debugger.stepOver",
            params: {
              skipList: [
          
              ]
            }
          },
          {
            id: 20,
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
              endLine: 7,
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
                    lineNumber: 2,
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
            id: 21,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "249684c74b6e52ac6ef45990ece6e164",
              expression: "a",
              objectGroup: "watch-group",
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
            id: 21,
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
            id: 22,
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
            id: 23,
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
            id: 22,
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
                },
                {
                  name: "f",
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
            id: 23,
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
                },
                {
                  name: "f",
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
            id: 24,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "249684c74b6e52ac6ef45990ece6e164",
              expression: "a",
              objectGroup: "watch-group",
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
            id: 24,
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
            id: 25,
            method: "Debugger.stepOver",
            params: {
              skipList: [
          
              ]
            }
          },
          {
            id: 25,
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
              endLine: 7,
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
            id: 26,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "c9845cfbf14bfb534a516247d28e699d",
              expression: "a",
              objectGroup: "watch-group",
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
            id: 26,
            result: {
              result: {
                type: "number",
                description: /.+/,
                value: 4,
                objectId: /.+/
              }
            }
          },
          {
            id: 27,
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
            id: 28,
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
            id: 27,
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
                    value: 4,
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
                },
                {
                  name: "f",
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
            id: 28,
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
                    value: 4,
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
                },
                {
                  name: "f",
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
            id: 29,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "c9845cfbf14bfb534a516247d28e699d",
              expression: "a",
              objectGroup: "watch-group",
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
            id: 29,
            result: {
              result: {
                type: "number",
                description: /.+/,
                value: 4,
                objectId: /.+/
              }
            }
          },
          {
            id: 30,
            method: "Debugger.stepOver",
            params: {
              skipList: [
          
              ]
            }
          },
          {
            id: 30,
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
              endLine: 7,
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
                    lineNumber: 4,
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
            id: 31,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "b5aa856edfac6fd69923bad78711fb57",
              expression: "a",
              objectGroup: "watch-group",
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
            id: 31,
            result: {
              result: {
                type: "number",
                description: /.+/,
                value: 4,
                objectId: /.+/
              }
            }
          },
          {
            id: 32,
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
            id: 33,
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
            id: 32,
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
                    value: 4,
                    objectId: /.+/
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "d",
                  value: {
                    type: "number",
                    description: /.+/,
                    value: 4,
                    objectId: /.+/
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
                },
                {
                  name: "f",
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
            id: 33,
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
                    value: 4,
                    objectId: /.+/
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "d",
                  value: {
                    type: "number",
                    description: /.+/,
                    value: 4,
                    objectId: /.+/
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
                },
                {
                  name: "f",
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
            id: 34,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "b5aa856edfac6fd69923bad78711fb57",
              expression: "a",
              objectGroup: "watch-group",
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
            id: 34,
            result: {
              result: {
                type: "number",
                description: /.+/,
                value: 4,
                objectId: /.+/
              }
            }
          },
          {
            id: 35,
            method: "Debugger.stepOver",
            params: {
              skipList: [
          
              ]
            }
          },
          {
            id: 35,
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
              endLine: 7,
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
                    lineNumber: 5,
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
            id: 36,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "c0cea16455b6ec62f97edc6eadec2006",
              expression: "a",
              objectGroup: "watch-group",
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
            id: 36,
            result: {
              result: {
                type: "number",
                description: /.+/,
                value: 5,
                objectId: /.+/
              }
            }
          },
          {
            id: 37,
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
            id: 38,
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
            id: 37,
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
                    value: 5,
                    objectId: /.+/
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "d",
                  value: {
                    type: "number",
                    description: /.+/,
                    value: 4,
                    objectId: /.+/
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
                },
                {
                  name: "f",
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
            id: 38,
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
                    value: 5,
                    objectId: /.+/
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "d",
                  value: {
                    type: "number",
                    description: /.+/,
                    value: 4,
                    objectId: /.+/
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
                },
                {
                  name: "f",
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
            id: 39,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "c0cea16455b6ec62f97edc6eadec2006",
              expression: "a",
              objectGroup: "watch-group",
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
            id: 39,
            result: {
              result: {
                type: "number",
                description: /.+/,
                value: 5,
                objectId: /.+/
              }
            }
          },
          {
            id: 40,
            method: "Debugger.resume",
            params: {
              terminateOnResume: false
            }
          },
          {
            id: 40,
            result: {
            }
          }
        ]
      end
    end
  end
end

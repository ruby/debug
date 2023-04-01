# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__
  class WatchTest1680367761 < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| a = 2
      2| a += 1
      3| a += 1
      4| d = 4
      5| a += 1
      6| e = 5
      7| f = 6
    RUBY

    def test_1680367761
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
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "a126f00649ca00f0b32aba84149b1ea9",
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
            id: 10,
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
            id: 11,
            method: "Debugger.stepOver",
            params: {
              skipList: [
          
              ]
            }
          },
          {
            id: 11,
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
            id: 12,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "a126f00649ca00f0b32aba84149b1ea9",
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
            id: 12,
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
            id: 13,
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
            id: 13,
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
            id: 14,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "6942cc45103f29405a912664c8e4f1fc",
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
                type: "number",
                description: /.+/,
                value: 2,
                objectId: /.+/
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
            id: 16,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "6942cc45103f29405a912664c8e4f1fc",
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
            id: 16,
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
            id: 18,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "59cd2941422d2a90b887393f6ab12291",
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
            method: "Debugger.stepOver",
            params: {
              skipList: [
          
              ]
            }
          },
          {
            id: 19,
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
            id: 20,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "59cd2941422d2a90b887393f6ab12291",
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
            id: 20,
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
            id: 21,
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
            id: 21,
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
            id: 22,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "75b24efedc7d4376c056f9de46e682e2",
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
            id: 22,
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
            id: 23,
            method: "Debugger.stepOver",
            params: {
              skipList: [
          
              ]
            }
          },
          {
            id: 23,
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
            id: 24,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "75b24efedc7d4376c056f9de46e682e2",
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
                value: 4,
                objectId: /.+/
              }
            }
          },
          {
            id: 25,
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
            id: 25,
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
            id: 26,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "f09c1dd6f3726f4615e1eecee097699d",
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
            method: "Debugger.stepOver",
            params: {
              skipList: [
          
              ]
            }
          },
          {
            id: 27,
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
            id: 28,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "f09c1dd6f3726f4615e1eecee097699d",
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
            id: 28,
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
            id: 29,
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
            id: 29,
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
            id: 30,
            method: "Debugger.evaluateOnCallFrame",
            params: {
              callFrameId: "17f8a6576d5c28763f42a0c7aadd3e4b",
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
            id: 30,
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
            id: 31,
            method: "Debugger.resume",
            params: {
              terminateOnResume: false
            }
          },
          {
            id: 31,
            result: {
            }
          }
        ]
      end
    end
  end
end

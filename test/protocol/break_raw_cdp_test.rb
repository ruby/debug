# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  
  class BreakTest1647164808 < TestCase
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
    
    def test_1647164808
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
              scriptSource: "module Foo\n  class Bar\n    def self.a\n      \"hello\"\n    end\n  end\n  Bar.a\n  bar = Bar.new\nend\n"
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
                columnNumber: 13
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
            method: "Debugger.setBreakpointsActive",
            params: {
              active: true
            }
          },
          {
            id: 15,
            result: {
            }
          },
          {
            id: 16,
            method: "Debugger.setBreakpointByUrl",
            params: {
              lineNumber: 6,
              urlRegex: "#{File.realpath(temp_file_path)}|file://#{File.realpath(temp_file_path)}",
              columnNumber: 0,
              condition: ""
            }
          },
          {
            id: 16,
            result: {
              breakpointId: /.+/,
              locations: [
                {
                  scriptId: /.+/,
                  lineNumber: 6
                }
              ]
            }
          },
          {
            id: 17,
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
                columnNumber: 13
              },
              restrictToFunction: false
            }
          },
          {
            id: 18,
            method: "Debugger.getPossibleBreakpoints",
            params: {
              start: {
                scriptId: "1",
                lineNumber: 6,
                columnNumber: 0
              },
              end: {
                scriptId: "1",
                lineNumber: 6,
                columnNumber: 7
              },
              restrictToFunction: false
            }
          },
          {
            id: 17,
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
            id: 18,
            result: {
              locations: [
                {
                  scriptId: /.+/,
                  lineNumber: 6
                }
              ]
            }
          },
          {
            id: 19,
            method: "Debugger.setBreakpointsActive",
            params: {
              active: true
            }
          },
          {
            id: 19,
            result: {
            }
          },
          {
            id: 20,
            method: "Debugger.setBreakpointByUrl",
            params: {
              lineNumber: 7,
              urlRegex: "#{File.realpath(temp_file_path)}|file://#{File.realpath(temp_file_path)}",
              columnNumber: 0,
              condition: ""
            }
          },
          {
            id: 20,
            result: {
              breakpointId: /.+/,
              locations: [
                {
                  scriptId: /.+/,
                  lineNumber: 7
                }
              ]
            }
          },
          {
            id: 21,
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
                columnNumber: 13
              },
              restrictToFunction: false
            }
          },
          {
            id: 22,
            method: "Debugger.getPossibleBreakpoints",
            params: {
              start: {
                scriptId: "1",
                lineNumber: 6,
                columnNumber: 0
              },
              end: {
                scriptId: "1",
                lineNumber: 6,
                columnNumber: 7
              },
              restrictToFunction: false
            }
          },
          {
            id: 21,
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
            id: 23,
            method: "Debugger.getPossibleBreakpoints",
            params: {
              start: {
                scriptId: "1",
                lineNumber: 7,
                columnNumber: 0
              },
              end: {
                scriptId: "1",
                lineNumber: 7,
                columnNumber: 15
              },
              restrictToFunction: false
            }
          },
          {
            id: 22,
            result: {
              locations: [
                {
                  scriptId: /.+/,
                  lineNumber: 6
                }
              ]
            }
          },
          {
            id: 23,
            result: {
              locations: [
                {
                  scriptId: /.+/,
                  lineNumber: 7
                }
              ]
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
            method: "Debugger.paused",
            params: {
              reason: "other",
              callFrames: [
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
              ]
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
            id: 26,
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
                    className: "Module"
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "bar",
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
            result: {
              result: [
                {
                  name: "%self",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "Module"
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "bar",
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
            id: 27,
            method: "Debugger.resume",
            params: {
              terminateOnResume: false
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
              reason: "other",
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
              ]
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
            id: 28,
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
                }
              ]
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
                    className: "Class"
                  },
                  configurable: true,
                  enumerable: true
                }
              ]
            }
          },
          {
            id: 30,
            method: "Debugger.resume",
            params: {
              terminateOnResume: false
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
              reason: "other",
              callFrames: [
                {
                  callFrameId: /.+/,
                  functionName: "<module:Foo>",
                  functionLocation: {
                    lineNumber: 0,
                    scriptId: /.+/
                  },
                  location: {
                    lineNumber: 7,
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
              ]
            }
          },
          {
            id: 31,
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
            id: 31,
            result: {
              result: [
                {
                  name: "%self",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "Module"
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "bar",
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
            id: 32,
            result: {
              result: [
                {
                  name: "%self",
                  value: {
                    type: "object",
                    description: /.+/,
                    objectId: /.+/,
                    className: "Module"
                  },
                  configurable: true,
                  enumerable: true
                },
                {
                  name: "bar",
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
            method: "Debugger.resume",
            params: {
              terminateOnResume: false
            }
          },
          {
            id: 33,
            result: {
            }
          }
        ]
      end
    end
  end
end

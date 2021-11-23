# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class BootConfigTest < TestCase
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

    def test_boot_configuration_works_correctly
      run_cdp_scenario PROGRAM do
        cdp_req({
          "id": 1,
          "method": "Page.getResourceTree",
          "params": {
          }
        })
        assert_cdp_res({
          "id": 1,
          "result": {
            "frameTree": {
              "frame": {
                "id": /.+/,
                "loaderId": /.+/,
                "url": /http:\/\/debuggee.+/,
                "securityOrigin": "http://debuggee",
                "mimeType": "text/plain"
              },
              "resources": [
              ]
            }
          }
        })
        assert_cdp_evt({
          "method": "Debugger.scriptParsed",
          "params": {
            "scriptId": /#{temp_file_path}/,
            "url": /http:\/\/debuggee.+/,
            "startLine": 0,
            "startColumn": 0,
            "endLine": 9,
            "endColumn": 0,
            "executionContextId": 1,
            "hash": /.+/
          }
        })
        assert_cdp_evt({
          "method": "Runtime.executionContextCreated",
          "params": {
            "context": {
              "id": /.+/,
              "origin": /http:\/\/.+:#{TCPIP_PORT}/,
              "name": ""
            }
          }
        })
        cdp_req({
          "id": 2,
          "method": "Debugger.getScriptSource",
          "params": {
            "scriptId": temp_file_path
          }
        })
        assert_cdp_res({
          "id": 2,
          "result": {
            "scriptSource": File.read(temp_file_path)
          }
        })
        assert_cdp_evt({
          "method": "Debugger.paused",
          "params": {
            "callFrames": [
              {
                "callFrameId": /.+/,
                "functionName": "<main>",
                "location": {
                  "scriptId": /#{temp_file_path}/,
                  "lineNumber": 0
                },
                "url": /http:\/\/debuggee.+/,
                "scopeChain": [
                  {
                    "type": "local",
                    "object": {
                      "type": "object",
                      "objectId": /.+/
                    }
                  },
                  {
                    "type": "script",
                    "object": {
                      "type": "object",
                      "objectId": /.+/
                    }
                  },
                  {
                    "type": "global",
                    "object": {
                      "type": "object",
                      "objectId": /.+/
                    }
                  }
                ],
                "this": {
                  "type": "object"
                }
              }
            ],
            "reason": "other"
          }
        })
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class BootConfigTest < TestCase
    PROGRAM = <<~RUBY
        a = 1
      RUBY
    def test_boot_configuration_works_correctly
      run_cdp_scenario PROGRAM do
        cdp_request 'Page.getResourceTree'
        assert_cdp_res 'http://debuggee/', 'frameTree', 'frame', 'url'

        assert_cdp_evt "http://127.0.0.1:#{TCPIP_PORT}", 'Runtime.executionContextCreated', 'context', 'origin'

        sid = find_cdp_evt('Debugger.scriptParsed').dig('params', 'scriptId')
        cdp_request 'Debugger.getScriptSource', scriptId: sid
        assert_cdp_res PROGRAM, 'scriptSource'

        assert_cdp_evt 'other', 'Debugger.paused', 'reason'
        assert_cdp_evt 0, 'Debugger.paused', 'callFrames', 0, 'location', 'lineNumber'
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__

  class DisconnectDAPTest < ProtocolTestCase
    PROGRAM = <<~RUBY
       1| module Foo
       2|   class Bar
       3|     def self.a
       4|       "hello"
       5|     end
       6|   end
       7|   loop do
       8|     b = 1
       9|   end
      10|   Bar.a
      11|   bar = Bar.new
      12| end
    RUBY

    def test_disconnect_without_terminateDebuggee_keeps_debuggee_alive
      run_protocol_scenario PROGRAM, cdp: false do
        req_dap_disconnect(terminate_debuggee: false)
        attach_to_dap_server
        assert_reattached
        # suspends the debuggee so it'll take the later requests (include terminate)
        suspend_debugee
        req_terminate_debuggee
      end
    end

    def test_disconnect_with_terminateDebuggee_kills_debuggee
      run_protocol_scenario PROGRAM, cdp: false do
        req_dap_disconnect(terminate_debuggee: true)
      end
    end

    private

    def suspend_debugee
      send_dap_request "pause", threadId: 1
    end

    def assert_reattached
      res = find_crt_dap_response
      result_cmd = res.dig(:command)
      assert_equal 'configurationDone', result_cmd
    end
  end
end

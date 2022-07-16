# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__
  class DisconnectCDPTest < ProtocolTestCase
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

    def test_closing_cdp_connection_doesnt_kill_the_debuggee
      run_protocol_scenario PROGRAM, dap: false do
        req_cdp_disconnect
        attach_to_cdp_server
        req_terminate_debuggee
      end
    end
  end
end

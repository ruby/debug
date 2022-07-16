# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__

  class TerminateTest < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| a = 1
    RUBY

    def test_terminate_request_terminates_the_debuggee
      run_protocol_scenario PROGRAM do
        req_terminate_debuggee
      end
    end
  end
end

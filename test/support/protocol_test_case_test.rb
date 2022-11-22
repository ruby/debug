# frozen_string_literal: true

require_relative 'protocol_test_case'

module DEBUGGER__
  class TestFrameworkTestHOge < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| a=1
    RUBY

    def test_the_test_fails_when_debuggee_doesnt_exit
      assert_fail_assertion do
        run_protocol_scenario PROGRAM do
        end
      end
    end
  end
end

# frozen_string_literal: true

require_relative 'protocol_test_case'

module DEBUGGER__
  class TestProtocolTestCase < ProtocolTestCase
    def test_the_test_fails_when_debuggee_doesnt_exit
      omit "too slow now"

      program = <<~RUBY
        1| a=1
      RUBY

      assert_fail_assertion do
        run_protocol_scenario program do
        end
      end
    end

    def test_the_assertion_failure_takes_presedence_over_debuggee_not_exiting
      program = <<~RUBY
        1| a = 2
        2| b = 3
      RUBY

      assert_raise_message(/<\"100\"> expected but was/) do
        run_protocol_scenario program do
          req_add_breakpoint 2
          req_continue
          assert_repl_result({value: '100', type: 'Integer'}, 'a')
        end
      end
    end
  end
end

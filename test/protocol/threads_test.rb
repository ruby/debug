# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__
  class ThreadsTest < ProtocolTestCase
    PROGRAM = <<~RUBY
       1| def foo
       2|   Thread.new { sleep 30 }
       3| end
       4|
       5| foo
       6| sleep 0.1 # make sure the thread stops
       7| binding.b
    RUBY

    def test_reponse_returns_correct_threads_info
      run_protocol_scenario PROGRAM, cdp: false do
        req_continue

        assert_threads_result(
          [
            /\.rb:\d:in [`']<main>'/,
            /\.rb:\d:in [`']block in (Object#)?foo'/
          ]
        )

        req_terminate_debuggee
      end
    end
  end
end


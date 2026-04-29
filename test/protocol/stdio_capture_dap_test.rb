# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__
  class StdioCaptureDAPTest < ProtocolTestCase
    PROGRAM = <<~RUBY
       1| $stdout.puts "stdout message"
       2| $stderr.puts "stderr message"
       3| a = 1
    RUBY

    def test_stdout_captured_as_output_event
      run_protocol_scenario PROGRAM, cdp: false do
        req_add_breakpoint 3
        req_continue

        stdout_event = find_response :event, 'output', 'V<D'
        assert_equal 'stdout', stdout_event.dig(:body, :category)
        assert_match(/stdout message/, stdout_event.dig(:body, :output))

        req_terminate_debuggee
      end
    end

    def test_stderr_captured_as_output_event
      run_protocol_scenario PROGRAM, cdp: false do
        req_add_breakpoint 3
        req_continue

        find_response :event, 'output', 'V<D'
        stderr_event = find_response :event, 'output', 'V<D'
        assert_equal 'stderr', stderr_event.dig(:body, :category)
        assert_match(/stderr message/, stderr_event.dig(:body, :output))

        req_terminate_debuggee
      end
    end
  end
end

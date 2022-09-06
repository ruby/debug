# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__
  class CallStackWithSkipDAPTest < ProtocolTestCase
    def program(path)
      <<~RUBY
        1| require_relative "#{path}"
        2| with_foo do
        3|  "something"
        4| end
      RUBY
    end

    def extra_file
      <<~RUBY
        def with_foo
          yield
        end
      RUBY
    end

    def req_stacktrace_file_names
      response = send_dap_request('stackTrace', threadId: 1)
      stack_frames = response.dig(:body, :stackFrames)
      stack_frames.map { |f| f.dig(:source, :name) }
    end

    def test_it_does_not_skip_a_path
      with_extra_tempfile do |extra_file|
        run_protocol_scenario(program(extra_file.path), cdp: false) do
          req_add_breakpoint 3
          req_continue

          assert_equal(
            [File.basename(temp_file_path), File.basename(extra_file.path), File.basename(temp_file_path)],
            req_stacktrace_file_names
          )

          req_terminate_debuggee
        end
      end
    end

    def test_it_skips_a_path
      with_extra_tempfile do |extra_file|
        ENV['RUBY_DEBUG_SKIP_PATH'] = extra_file.path
        run_protocol_scenario(program(extra_file.path), cdp: false) do
          req_add_breakpoint 3
          req_continue

          assert_equal([File.basename(temp_file_path), File.basename(temp_file_path)], req_stacktrace_file_names)

          req_terminate_debuggee
        end
      end
    ensure
      ENV['RUBY_DEBUG_SKIP_PATH'] = nil
    end
  end
end

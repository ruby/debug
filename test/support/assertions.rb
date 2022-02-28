# frozen_string_literal: true

module DEBUGGER__
  module AssertionHelpers
    def assert_line_num(expected)
      case ENV['RUBY_DEBUG_TEST_UI']
      when 'terminal'
        @scenario.push(Proc.new { |test_info|
          msg = "Expected line number to be #{expected.inspect}, but was #{test_info.internal_info['line']}\n"

          assert_block(FailureMessage.new { create_message(msg, test_info) }) do
            expected == test_info.internal_info['line']
          end
        })
      when 'vscode'
        send_request 'stackTrace',
                      threadId: 1,
                      startFrame: 0,
                      levels: 20
        res = find_crt_dap_response
        failure_msg = FailureMessage.new{create_protocol_message "result:\n#{JSON.pretty_generate res}"}
        result = res.dig(:body, :stackFrames, 0, :line)
        assert_equal expected, result, failure_msg
      when 'chrome'
        failure_msg = FailureMessage.new{create_protocol_message "result:\n#{JSON.pretty_generate @crt_frames}"}
        result = @crt_frames.dig(0, :location, :lineNumber) + 1
        assert_equal expected, result, failure_msg
      else
        raise 'Invalid environment variable'
      end
    end

    def assert_line_text(text)
      @scenario.push(Proc.new { |test_info|
        result = collect_recent_backlog(test_info.last_backlog)

        expected =
          case text
          when Array
            case text.first
            when String
              text.map { |s| Regexp.escape(s) }.join
            when Regexp
              Regexp.compile(text.map(&:source).join('.*'), Regexp::MULTILINE)
            end
          when String
            Regexp.escape(text)
          when Regexp
            text
          else
            raise "Unknown expectation value: #{text.inspect}"
          end

        msg = "Expected to include `#{expected.inspect}` in\n(\n#{result})\n"

        assert_block(FailureMessage.new { create_message(msg, test_info) }) do
          result.match? expected
        end
      })
    end

    def assert_no_line_text(text)
      @scenario.push(Proc.new { |test_info|
        result = collect_recent_backlog(test_info.last_backlog)
        if text.is_a?(String)
          expected = Regexp.escape(text)
        else
          expected = text
        end
        msg = "Expected not to include `#{expected.inspect}` in\n(\n#{result})\n"

        assert_block(FailureMessage.new { create_message(msg, test_info) }) do
          !result.match? expected
        end
      })
    end

    def assert_debuggee_line_text text
      @scenario.push(Proc.new {|test_info|
        next if test_info.mode == 'LOCAL'

        log = test_info.remote_info.debuggee_backlog.join
        msg = "Expected to include `#{text.inspect}` in\n(\n#{log})\n"

        assert_block(FailureMessage.new{create_message(msg, test_info)}) do
          log.match? text
        end
      })
    end

    def assert_block msg
      if multithreaded_test?
        # test-unit doesn't support multi thread
        # FYI: test-unit/test-unit#204
        throw :fail, msg.to_s unless yield
      else
        super
      end
    end

    private

    def collect_recent_backlog(last_backlog)
      last_backlog[1..].join
    end
  end
end

class FailureMessage
  def initialize &block
    @msg = nil
    @create_msg = block
  end

  def to_s
    return @msg if @msg

    @msg = @create_msg.call
  end
end

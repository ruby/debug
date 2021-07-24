# frozen_string_literal: true

module DEBUGGER__
  module AssertionHelpers
    def assert_line_num(expected)
      @queue.push(Proc.new {
        msg = "Expected line number to be #{expected.inspect}, but was #{@internal_info['line']}\n"
        assert_block(FailureMessage.new { create_message(msg) }) { expected == @internal_info['line'] }
      })
    end

    def assert_line_text(expected)
      @queue.push(Proc.new {
        result = collect_recent_backlog

        expected =
          case expected
          when Array
            case expected.first
            when String
              expected.map { |s| Regexp.escape(s) }.join
            when Regexp
              Regexp.compile(expected.map(&:source).join('.*'), Regexp::MULTILINE)
            end
          when String
            Regexp.escape(expected)
          when Regexp
            expected
          else
            raise "Unknown expectation value: #{expected.inspect}"
          end

        msg = "Expected to include `#{expected.inspect}` in\n(\n#{result})\n"

        assert_block(FailureMessage.new { create_message(msg) }) do
          result.match? expected
        end
      })
    end

    def assert_no_line_text(expected)
      @queue.push(Proc.new {
        result = collect_recent_backlog
        expected = Regexp.escape(expected) if expected.is_a?(String)
        msg = "Expected not to include `#{expected.inspect}` in\n(\n#{result})\n"

        assert_block(FailureMessage.new { create_message(msg) }) do
          !result.match? expected
        end
      })
    end

    private

    def collect_recent_backlog
      @last_backlog[1..].join
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

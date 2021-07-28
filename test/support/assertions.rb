# frozen_string_literal: true

module DEBUGGER__
  module AssertionHelpers
    def assert_line_num(expected)
      @queue.push(Proc.new {
        msg = "Expected line number to be #{expected.inspect}, but was #{@internal_info['line']}\n"
        assert_block(FailureMessage.new { create_message(msg) }) { expected == @internal_info['line'] }
      })
    end

    def assert_line_text(text)
      @queue.push(Proc.new {
        result = collect_recent_backlog

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

        assert_block(FailureMessage.new { create_message(msg) }) do
          result.match? expected
        end
      })
    end

    def assert_no_line_text(text)
      @queue.push(Proc.new {
        result = collect_recent_backlog
        if text.is_a?(String)
          expected = Regexp.escape(text)
        else
          expected = text
        end
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

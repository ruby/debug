# frozen_string_literal: true

module DEBUGGER__
  module AssertionHelpers
    def assert_line_num(expected)
      @queue.push(Proc.new {
        msg = "Expected line number to be #{expected}, but was #{@internal_info['line']}\n"
        assert_block(MessageCreationController.new { create_message(msg) }) { expected == @internal_info['line'] }
      })
    end

    def assert_line_text(expected)
      @queue.push(Proc.new {
        result = collect_recent_backlog
        expected = Regexp.escape(expected) if expected.is_a?(String)
        msg = "Expected to include `#{expected}` in\n(\n#{result})\n"

        assert_block(MessageCreationController.new { create_message(msg) }) do
          result.match? expected
        end
      })
    end

    def assert_no_line_text(expected)
      @queue.push(Proc.new {
        result = collect_recent_backlog
        expected = Regexp.escape(expected) if expected.is_a?(String)
        msg = "Expected not to include `#{expected}` in\n(\n#{result})\n"

        assert_block(MessageCreationController.new { create_message(msg) }) do
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

class MessageCreationController
  def initialize &block
    @msg = nil
    @create_msg = block
  end

  def to_s
    return @msg if @msg

    @msg = @create_msg.call
  end
end

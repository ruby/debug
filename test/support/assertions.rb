# frozen_string_literal: true

module DEBUGGER__
  module AssertionHelpers
    def assert_line_num(exp)
      @scenario.push(Proc.new { |test_info|
        msg = "Expected line number to be #{exp.inspect}, but was #{test_info.internal_info['line']}\n"

        assert_block(FailureMessage.new { create_message(msg, test_info) }) do
          exp == test_info.internal_info['line']
        end
      })
    end

    def assert_debugger_out(exp)
      @scenario.push(Proc.new { |test_info|
        result = collect_recent_backlog(test_info.last_backlog)

        expected =
          case exp
          when Array
            case exp.first
            when String
              exp.map { |s| Regexp.escape(s) }.join
            when Regexp
              Regexp.compile(exp.map(&:source).join('.*'), Regexp::MULTILINE)
            end
          when String
            Regexp.escape(exp)
          when Regexp
            exp
          else
            raise "Unknown expectation value: #{exp.inspect}"
          end

        msg = "Expected to include `#{expected.inspect}` in\n(\n#{result})\n"

        assert_block(FailureMessage.new { create_message(msg, test_info) }) do
          result.match? expected
        end
      })
    end

    def assert_debugger_noout(exp)
      @scenario.push(Proc.new { |test_info|
        result = collect_recent_backlog(test_info.last_backlog)
        if exp.is_a?(String)
          expected = Regexp.escape(exp)
        else
          expected = exp
        end
        msg = "Expected not to include `#{expected.inspect}` in\n(\n#{result})\n"

        assert_block(FailureMessage.new { create_message(msg, test_info) }) do
          !result.match? expected
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

    def assert_finish
      @scenario.push(method(:flunk_finish))
    end

    private

    def collect_recent_backlog(last_backlog)
      last_backlog[1..].join
    end

    def flunk_finish test_info
      msg = 'Expected the debugger program to finish'

      assert_block(FailureMessage.new { create_message(msg, test_info) }) { false }
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

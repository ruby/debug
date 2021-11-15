# frozen_string_literal: true

module DEBUGGER__
  module AssertionHelpers
    def assert_line_num(expected)
      @scenario.push(Proc.new { |test_info|
        msg = "Expected line number to be #{expected.inspect}, but was #{test_info.internal_info['line']}\n"

        assert_block(FailureMessage.new { create_message(msg, test_info) }) do
          expected == test_info.internal_info['line']
        end
      })
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

    def assert_finish
      @scenario.push(method(:flunk_finish))
    end

    def assert_cdp_res expected
      result = @last_cdp_res
      res = ProtocolParser.new.parse expected
      res.each{|r|
        k, v = r
        case v
        when Regexp
          assert_match v, result.dig(*k).to_s, FailureMessage.new{@ws_client.backlog.join("\n> ")}
        else
          assert_equal v, result.dig(*k), FailureMessage.new{@ws_client.backlog.join("\n> ")}
        end
      }
    end

    def assert_cdp_evt expected
      result = nil
      @reader_thread[:cdp_res].reverse_each{|r|
        if r[:method] == expected[:method]
          result = r
          break
        end
      }
      flunk "CDP Event: #{expected[:method]} was not found in #{@reader_thread[:cdp_res]}" if result.nil?

      req = ProtocolParser.new.parse expected
      req.each{|r|
        k, v = r
        case v
        when Regexp
          assert_match v, result.dig(*k).to_s, FailureMessage.new{@ws_client.backlog.join("\n> ")}
        else
          assert_equal v, result.dig(*k), FailureMessage.new{@ws_client.backlog.join("\n> ")}
        end
      }
    end

    private

    def collect_recent_backlog(last_backlog)
      last_backlog[1..].join
    end

    def flunk_finish test_info
      msg = 'Expected the debugger program to finish'

      assert_block(FailureMessage.new { create_message(msg, test_info) }) { false }
    end

    class ProtocolParser
      def initialize
        @result = []
        @keys = []
      end

      def parse objs
        objs.each{|k, v|
          parse_ k, v
          @keys.pop
        }
        @result
      end

      def parse_ k, v
        @keys << k
        case v
        when Array
          v.each.with_index{|v, i|
            parse_ i, v
            @keys.pop
          }
        when Hash
          v.each{|k, v|
            parse_ k, v
            @keys.pop
          }
        else
          @result << [@keys.dup, v]
        end
      end
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

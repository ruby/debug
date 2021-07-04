# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class TraceTest < TestCase
    def program
      <<~RUBY
     1| def foo
     2|   10
     3| end
     4|
     5| a = 1
     6| foo + a
     7|
     8| binding.bp
     9| __END__
      RUBY
    end

    def test_trace_on_starts_tracing
      debug_code(program) do
        type "trace on"
        type "continue"

        trace_regexps = [
          /Tracing:   line at .*rb:5\r\n/,
          /Tracing:   line at .*rb:6\r\n/,
          /Tracing:   call Object#foo at .*rb:1\r\n/,
          /Tracing:    line at .*rb:2\r\n/,
          /Tracing:   return Object#foo => 10 at .*rb:3\r\n/,
          /Tracing:   line at .*rb:8\r\n/,
        ]
        assert_line_text(trace_regexps)

        type "q!"
      end
    end

    def test_trace_off_stops_tracing
      debug_code(program) do
        type "b 6"
        type "trace on"
        type "continue"

        trace_regexps = [
          /Tracing:   line at .*rb:5\r\n/,
          /Tracing:   line at .*rb:6\r\n/,
        ]

        assert_line_text(trace_regexps)

        type "trace off"
        assert_no_line_text(/Tracing:   call Object#foo at .*rb:1\r\n/)

        type "q!"
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class TraceTest < TestCase
    def program
      <<~RUBY
     1| def foo a
     2|   10 + a
     3| end
     4|
     5| a = 1
     6| foo(a)
     7| a = nil
      RUBY
    end

    def test_trace
      debug_code(program) do
        type 'trace'
        assert_line_text /Tracers/
        type 'trace line'
        type 'trace call'
        type 'trace'
        type 'q!'
      end
    end

    def test_trace_off
      debug_code(program) do
        type 'trace'
        assert_line_text /Tracers/
        type 'trace line'
        type 'trace call'
        type 'trace'
        assert_line_text [/#0 LineTracer \(enabled\)/, /#1 CallTracer \(enabled\)/]
        type 'trace off 0'
        type 'trace'
        assert_line_text [/#0 LineTracer \(disabled\)/, /#1 CallTracer \(enabled\)/]
        type 'trace off 0'
        type 'trace'
        assert_line_text [/#0 LineTracer \(disabled\)/, /#1 CallTracer \(enabled\)/]
        type 'trace off 1'
        type 'trace'
        assert_line_text [/#0 LineTracer \(disabled\)/, /#1 CallTracer \(disabled\)/]
        type 'trace off 1'
        type 'trace'
        assert_line_text [/#0 LineTracer \(disabled\)/, /#1 CallTracer \(disabled\)/]
        type 'q!'
      end
    end

    def test_trace_line
      debug_code(program) do
        type 'b 6'
        type 'trace line'
        assert_line_text /Enable LineTracer/
        type 'c'
        assert_line_text /trace\/line/
        type 'q!'
      end
    end

    def test_trace_call
      debug_code(program) do
        type 'b 6'
        type 'trace call'
        assert_line_text /Enabble CallTracer/
        type 'c'
        #assert_line_text /trace\/call/
        type 'q!'
      end
    end

    def test_trace_pass
      debug_code(program) do
        type 'b 7'
        type 'trace pass 1'
        assert_line_text /Enable PassTracer/
        type 'c'
        assert_line_text /trace\/pass/
        type 'q!'
      end
    end

  end
end

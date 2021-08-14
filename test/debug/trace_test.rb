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
     8| begin
     9|   raise 'foo'
    10| rescue
    11|   nil
    12| end
      RUBY
    end

    def test_trace
      debug_code(program) do
        type 'trace'
        assert_line_text(/Tracers/)
        type 'trace line'
        type 'trace call'
        type 'trace'
        type 'q!'
      end
    end

    def test_trace_off
      debug_code(program) do
        type 'trace'
        assert_line_text(/Tracers/)
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
        assert_line_text(/Enable LineTracer/)
        type 'c'
        assert_line_text(/trace\/line/)
        type 'q!'
      end
    end

    def test_trace_call
      debug_code(program) do
        type 'b 7'
        type 'trace call'
        assert_line_text(/Enable CallTracer/)
        type 'c'
        assert_line_text(
          [
            /Object#foo at/,
            /Object#foo #=> 11/
          ]
        )
        type 'q!'
      end
    end

    def test_trace_raise
      debug_code(program) do
        type 'b 11'
        type 'trace raise'
        assert_line_text(/Enable RaiseTracer/)
        type 'c'
        assert_line_text(/trace\/raise.+RuntimeError: foo/)
        type 'q!'
      end
    end

    def test_trace_pass
      debug_code(program) do
        type 'b 7'
        type 'trace pass 1'
        assert_line_text(/Enable PassTracer/)
        type 'c'
        assert_line_text(/trace\/pass/)
        type 'q!'
      end
    end

  end

  class TracePassTest < TestCase
    def program
      if RUBY_VERSION >= "2.7"
        <<~RUBY
       1| def foo(...); end
       2| def bar(a:); end
       3| def baz(**kw); end
       4|
       5| foo(1)
       6| bar(a: 2)
       7| baz(b: 3)
       8|
       9| binding.b
        RUBY
      else
        <<~RUBY
       1| def bar(a:); end
       2| def baz(**kw); end
       3|
       4| bar(a: 2)
       5| baz(b: 3)
       6|
       7| binding.b
        RUBY
      end
    end

    def test_not_tracing_anonymous_rest_argument
      debug_code(program) do
        type 'trace pass 1'
        assert_line_text(/Enable PassTracer/)
        type 'c'
        assert_no_line_text(/trace\/pass/)
        type 'q!'
      end
    end if RUBY_VERSION >= "2.7"

    def test_tracing_key_argument
      debug_code(program) do
        type 'trace pass 2'
        assert_line_text(/Enable PassTracer/)
        type 'c'
        assert_line_text(/`2` is used as a parameter `a` of Object#bar/)
        type 'q!'
      end
    end

    def test_tracing_keyrest_argument
      debug_code(program) do
        type 'trace pass 3'
        assert_line_text(/Enable PassTracer/)
        type 'c'
        assert_line_text(/`3` is used as a parameter in `kw` of Object#baz/)
        type 'q!'
      end
    end
  end
end

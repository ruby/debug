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

    def test_trace_with_into
      into_file = Tempfile.create(%w[tracer_into .rb])

      debug_code(program, remote: false) do
        type "trace call into: #{into_file.path}"
        type 'c'
      end

      traces = into_file.read
      assert_match(/PID:\d+ CallTracer/, traces)
      assert_match(/Object#foo at/, traces)
      assert_match(/Object#foo #=> 11/, traces)
    ensure
      File.unlink(into_file) if into_file
    end
  end

  class TraceLineTest < TestCase
    def program
      <<~RUBY
     1| def foo
     2|   10
     3| end
     4|
     5| def bar
     6|   1
     7| end
     8|
     9| a = foo + bar
    10|
    11| binding.b
      RUBY
    end

    def test_trace_line_prints_line_execution
      debug_code(program) do
        type 'trace line'
        assert_line_text(/Enable LineTracer \(enabled\)/)
        type 'c'
        assert_line_text(/DEBUGGER \(trace\/line\)/)
        assert_line_text([
          /rb:5/,
          /rb:9/,
          /rb:2/,
          /rb:6/,
          /rb:11/,
        ])
        type 'q!'
      end
    end

    def test_trace_line_filters_output_with_file_path
      debug_code(program) do
        type 'trace line /debug/'
        assert_line_text(/Enable LineTracer/)
        type 'c'
        assert_line_text(/DEBUGGER \(trace\/line\)/)
        type 'q!'
      end

      debug_code(program) do
        type 'trace line /abc/'
        assert_line_text(/Enable LineTracer/)
        type 'c'

        assert_no_line_text(/DEBUGGER \(trace\/line\)/)
        type 'q!'
      end
    end
  end

  class TraceRaiseTest < TestCase
    def program
      <<~RUBY
     1| begin
     2|   raise "foo"
     3| rescue
     4| end
     5|
     6| binding.b
      RUBY
    end

    def test_trace_raise_prints_raised_exception
      debug_code(program) do
        type 'trace raise'
        assert_line_text(/Enable RaiseTracer/)
        type 'c'
        assert_line_text(/trace\/raise.+RuntimeError: foo/)
        type 'q!'
      end
    end

    def test_trace_raise_filters_output_with_file_path
      debug_code(program) do
        type 'trace raise /abc/'
        assert_line_text(/Enable RaiseTracer/)
        type 'c'
        assert_no_line_text(/trace\/raise.+RuntimeError: foo/)
        type 'q!'
      end

      debug_code(program) do
        type 'trace raise /debug/'
        assert_line_text(/Enable RaiseTracer/)
        type 'c'
        assert_line_text(/trace\/raise.+RuntimeError: foo/)
        type 'q!'
      end
    end
  end

  class TraceCallTest < TestCase
    def program
      <<~RUBY
     1| def foo
     2| end
     3|
     4| def bar
     5| end
     6|
     7| foo
     8| bar
     9|
    10| binding.b
      RUBY
    end

    def test_trace_call_prints_method_calls
      debug_code(program) do
        type 'trace call'
        assert_line_text(/Enable CallTracer/)
        type 'c'
        assert_line_text(
          [
            /Object#foo at/,
            /Object#foo #=> nil/,
            /Object#bar at/,
            /Object#bar #=> nil/
          ]
        )
        # tracer should ignore calls from associated libraries
        # for example, the test implementation relies on 'json' to generate test info, which's calls should be ignored
        assert_no_line_text(/JSON/)
        type 'q!'
      end
    end

    def test_trace_call_with_pattern_filters_output_with_method_name
      debug_code(program) do
        type 'trace call /bar/'
        assert_line_text(/Enable CallTracer/)
        type 'c'
        assert_no_line_text(/Object#foo at/)
        assert_line_text([
            /Object#bar at/,
            /Object#bar #=> nil/
          ]
        )
        type 'q!'
      end
    end

    def test_trace_call_with_pattern_filters_output_with_file_path
      debug_code(program) do
        type 'trace call /debug/'
        assert_line_text(/Enable CallTracer/)
        type 'c'
        assert_line_text(
          [
            /Object#foo at/,
            /Object#foo #=> nil/,
            /Object#bar at/,
            /Object#bar #=> nil/
          ]
        )
        type 'q!'
      end

      debug_code(program) do
        type 'trace call /not_a_path/'
        assert_line_text(/Enable CallTracer/)
        type 'c'
        assert_no_line_text(/Object#foo/)
        assert_no_line_text(/Object#bar/)
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
        assert_line_text(/2 is used as a parameter a of Object#bar/)
        type 'q!'
      end
    end

    def test_tracing_keyrest_argument
      debug_code(program) do
        type 'trace pass 3'
        assert_line_text(/Enable PassTracer/)
        type 'c'
        assert_line_text(/3 is used as a parameter in kw of Object#baz/)
        type 'q!'
      end
    end

    class TraceCallReceiverTest < TestCase
      def program
        <<~RUBY
         1| class Foo
         2|   def bar; end
         3|   def self.baz; end
         4| end
         5|
         6| class Bar < Foo
         7| end
         8|
         9| f = Foo.new
        10| b = Bar.new
        11|
        12| def f.foobar; end
        13| def b.foobar; end
        14|
        15| binding.b
        16|
        17|  Foo.baz
        18|  f.bar
        19|  f.foobar
        20|
        21|  Bar.baz
        22|  b.bar
        23|  b.foobar
        24|
        25|  binding.b
        RUBY
      end

      def test_tracer_prints_correct_method_receiving_messages
        debug_code(program) do
          type 'c'
          type 'trace pass Foo'
          type 'trace pass f'
          type 'c'
          assert_line_text([
            /Foo receives .baz \(#<Class:Foo>.baz\) at/,
            /#<Foo:.*> receives #bar \(Foo#bar\) at/,
            /#<Foo:.*> receives .foobar/
          ])
          type 'c'
        end

        debug_code(program) do
          type 'c'
          type 'trace pass Bar'
          type 'trace pass b'
          type 'c'
          assert_line_text([
            /Bar receives .baz \(#<Class:Foo>.baz\) at/,
            /#<Bar:.*> receives #bar \(Foo#bar\) at/,
            /#<Bar:.*> receives .foobar/
          ])
          type 'c'
        end
      end
    end
  end
end

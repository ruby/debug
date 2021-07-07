# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class BasicBacktraceTest < TestCase
    def program
      <<~RUBY
     1| class Foo
     2|   def first_call
     3|     second_call(20)
     4|   end
     5|
     6|   def second_call(num)
     7|     third_call_with_block do |ten|
     8|       num + ten
     9|     end
    10|   end
    11|
    12|   def third_call_with_block(&block)
    13|     yield(10)
    14|   end
    15| end
    16|
    17| 3.times do
    18|   Foo.new.first_call
    19| end
      RUBY
    end

    def test_backtrace_prints_c_method_frame
      debug_code(program) do
        type 'b 18'
        type 'c'
        type 'bt'
        assert_line_text(/\[C\] Integer#times/)
        type 'q!'
      end
    end

    def test_backtrace_prints_the_return_value
      debug_code(program) do
        type 'b 4'
        type 'c'
        type 'bt'
        assert_line_text(/Foo#first_call .* #=> 30/)
        type 'q!'
      end
    end

    def test_backtrace_prints_method_arguments
      debug_code(program) do
        type 'b 7'
        type 'c'
        type 'bt'
        assert_line_text(/Foo#second_call\(num=20\)/)
        type 'q!'
      end
    end

    def test_backtrace_prints_block_arguments
      debug_code(program) do
        type 'b 9'
        type 'c'
        type 'bt'
        assert_line_text(/block {\|ten=10\|}/)
        type 'q!'
      end
    end

    def test_backtrace_prints_a_given_number_of_traces
      debug_code(program) do
        type 'b 13'
        type 'c'
        type 'bt 2'
        assert_line_text(/Foo#third_call_with_block/)
        assert_line_text(/Foo#second_call/)
        assert_no_line_text(/Foo#first_call/)
        type 'q!'
      end
    end

    def test_backtrace_prints_traces_that_match_the_pattern
      debug_code(program) do
        type 'b 13'
        type 'c'
        type 'bt /rb:\d\z/'
        assert_line_text(/Foo#second_call/)
        assert_line_text(/Foo#first_call/)
        assert_no_line_text(/Foo#third_call_with_block/)
        type 'q!'
      end
    end

    def test_backtrace_takes_both_number_and_pattern
      debug_code(program) do
        type 'b 13'
        type 'c'
        type 'bt 1 /rb:\d\z/'
        assert_line_text(/Foo#second_call/)
        assert_no_line_text(/Foo#first_call/)
        type 'q!'
      end
    end
  end

  class BlockTraceTest < TestCase
    def program
      <<~RUBY
     1| tap do
     2|   tap do
     3|     p 1
     4|   end
     5| end
     6|
     7| __END__
      RUBY
    end

    def test_backtrace_prints_block_label_correctly
      debug_code(program) do
        type 'b 2'
        type 'c'
        type 'bt'
        assert_line_text(/block in <main> at/)
        type 'q!'
      end
    end

    def test_backtrace_prints_nested_block_label_correctly
      debug_code(program) do
        type 'b 3'
        type 'c'
        type 'bt'
        assert_line_text(/block in <main> \(2 levels\) at/)
        type 'q!'
      end
    end
  end
end

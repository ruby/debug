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
  end
end

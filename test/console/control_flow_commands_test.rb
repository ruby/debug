# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  #
  # Test basic control flow commands.
  #
  class BasicControlFlowTest < ConsoleTestCase
    def program
      <<~RUBY
         1| class Student
         2|   def initialize(name)
         3|     @name = name
         4|   end
         5|
         6|   def name
         7|     @name
         8|   end
         9| end
        10|
        11| s = Student.new("John")
        12| s.name
        13| "foo"
      RUBY
    end

    def test_step_goes_to_the_next_statement
      debug_code(program) do
        type 'b 11'
        type 'c'
        assert_line_num 11
        type 's'
        assert_line_num 3
        type 's'
        assert_line_num 4
        type 's'
        assert_line_num 12
        type 's'
        assert_line_num 7
        type 's'
        assert_line_num 8
        type 's'
        assert_line_num 13
        type 'quit'
        type 'y'
      end
    end

    def test_step_with_number_goes_to_the_next_nth_statement
      debug_code(program) do
        type 'b 11'
        type 'c'
        assert_line_num 11
        type 's 2'
        assert_line_num 4
        type 's 3'
        assert_line_num 8
        type 's'
        assert_line_num 13
        type 'quit'
        type 'y'
      end
    end

    def test_next_goes_to_the_next_line
      debug_code(program) do
        type 'b 11'
        type 'c'
        assert_line_num 11
        type 'n'
        assert_line_num 12
        type 'n'
        assert_line_num 13
        type 'quit'
        type 'y'
      end
    end

    def test_next_with_number_goes_to_the_next_nth_line
      debug_code(program) do
        type 'b 11'
        type 'c'
        assert_line_num 11
        type 'n 2'
        assert_line_num 13
        type 'quit'
        type 'y'
      end
    end

    def test_continue_goes_to_the_next_breakpoint
      debug_code(program) do
        type 'b 11'
        type 'c'
        assert_line_num 11
        type 'b 13'
        type 'c'
        assert_line_num 13
        type 'quit'
        type 'y'
      end
    end

    def test_finish_leaves_the_current_frame
      debug_code(program) do
        type 'b 11'
        type 'c'
        assert_line_num 11
        type 's'
        assert_line_num 3
        type 'fin'
        assert_line_num 4
        type 's'
        assert_line_num 12
        type 's'
        assert_line_num 7
        type 'fin'
        assert_line_num 8
        type 'kill!'
      end
    end
  end

  #
  # Tests control flow commands with block.
  #
  class BlockControlFlowTest < ConsoleTestCase
    def program
      <<~RUBY
        1| 2.times do |n|
        2|   n
        3| end
        4| :ok
      RUBY
    end

    def test_step_steps_out_of_blocks_when_done
      debug_code(program) do
        type 'step'
        assert_line_num 2
        type 'step'
        assert_line_num 3
        type 'step'
        assert_line_num 2
        type 'step'
        assert_line_num 3
        type 'step'
        assert_line_num 4
        type 'quit'
        type 'y'
      end
    end

    def test_next_steps_out_of_blocks_right_away
      debug_code(program) do
        type 'step'
        assert_line_num 2
        type 'next'
        assert_line_num 3
        type 'next'
        assert_line_num 2
        type 'next'
        assert_line_num 3
        type 'next'
        assert_line_num 4
        type 'quit'
        type 'y'
      end
    end
  end

  class FinishControlFlowTest < ConsoleTestCase
    def program
      <<~RUBY
      1| def foo
      2|   bar
      3| end
      4| def bar
      5|   baz
      6| end
      7| def baz
      8|   :baz
      9| end
     10| foo
     11| :ok
      RUBY
    end

    def test_finish
      debug_code program do
        type 'b 8'
        type 'c'
        assert_line_num 8
        type 'finish'
        assert_line_num 9
        type 'kill!'
      end
    end

    def test_finish_0
      debug_code program do
        type 'b 8'
        type 'c'
        assert_line_num 8
        type 'fin 0'
        assert_line_text(/finish command with 0 does not make sense/)
        type 'kill!'
      end
    end

    def test_finish_1
      debug_code program do
        type 'b 8'
        type 'c'
        assert_line_num 8
        type 'fin 1'
        assert_line_num 9
        type 'kill!'
      end
    end

    def test_finish_2
      debug_code program do
        type 'b 8'
        type 'c'
        assert_line_num 8
        type 'fin 2'
        assert_line_num 6
        type 'kill!'
      end
    end

    def test_finish_3
      debug_code program do
        type 'b 8'
        type 'c'
        assert_line_num 8
        type 'fin 3'
        assert_line_num 3
        type 'kill!'
      end
    end

    def test_finish_4
      debug_code program do
        type 'b 8'
        type 'c'
        assert_line_num 8
        type 'fin 4'
      end
    end


    def program2
      <<~RUBY
      1| def foo x
      2|   :foo
      3| end
      4| def bar
      5|   :bar
      6| end
      7| def baz
      8|   foo(bar())
      9| end
     10| baz
     11| :ok
      RUBY
    end

    def test_finish_param
      debug_code program2 do
        type 'b 5'
        type 'c'
        assert_line_num 5
        type 'finish'
        assert_line_num 6
        type 'next'
        assert_line_num 2
        type 'c'
      end
    end

    def test_finish_param2
      debug_code program2 do
        type 'b 5'
        type 'c'
        assert_line_num 5
        type 'finish 2'
        assert_line_num 9
        type 'c'
      end
    end
  end

  #
  # Test for https://github.com/ruby/debug/issues/89
  #
  class IfBlockControlFlowTest < ConsoleTestCase
    def program
      <<~RUBY
        1| if foo = nil
        2|   if foo
        3|   end
        4| end
        5|
        6| p 1
      RUBY
    end

    def test_next_steps_out_of_if_blocks_when_done
      debug_code(program) do
        type 'next'
        assert_line_num 6
        type 'quit'
        type 'y'
      end
    end

    def test_step_steps_out_of_if_blocks_when_done
      debug_code(program) do
        type 'step'
        assert_line_num 6
        type 'quit'
        type 'y'
      end
    end
  end

  #
  # Tests control flow commands with rescue.
  #
  class RescueControlFlowTest < ConsoleTestCase
    def program
      <<~RUBY
         1| module Foo
         2|   class Bar
         3|     def self.raise_error
         4|       raise
         5|     rescue
         6|       p $!
         7|     end
         8|   end
         9|   Bar.raise_error
        10| end
      RUBY
    end

    def test_next_steps_over_rescue_when_raising_from_method
      debug_code(program) do
        type 'break Foo::Bar.raise_error'
        type 'continue'
        assert_line_num 4
        type 'next'
        assert_line_num 6
        type 'quit'
        type 'y'
      end
    end
  end

  class CancelStepTest < ConsoleTestCase
    def program
      <<~RUBY
       1| def foo m
       2|  __send__ m
       3| end
       4| def bar
       5|   a = :bar1
       6|   b = :bar2
       7|   c = :bar3
       8| end
       9|
      10| def baz
      11|   :baz
      12| end
      13| foo :bar
      14| foo :baz
      15| foo :baz
      RUBY
    end

    def test_next_should_be_canceled
      debug_code program do
        type 'b 13'
        type 'b Object#bar'
        type 'c'
        assert_line_num 13
        type 'n'
        assert_line_num 5
        type 'c'
      end
    end

    def test_finish_should_be_canceled
      debug_code program do
        type 'b 5'
        type 'b 6'
        type 'c'
        assert_line_num 5
        type 'finish'
        assert_line_num 6
        type 'c'
      end
    end
  end

  class UntilTest < ConsoleTestCase
    def program
      <<~RUBY
      1| 3.times do
      2|   a = 1
      3|   b = 2
      4| end
      5| c = 3
      6| def foo
      7|   x = 1
      8| end
      9| foo
      RUBY
    end

    def test_until_line
      debug_code program do
        type 'u 2'
        assert_line_num 2
        type 'u'
        assert_line_num 3
        type 'u'
        assert_line_num 5
        type 'c'
      end
    end

    def test_until_line_overrun
      debug_code program do
        type 'u 2'
        assert_line_num 2
        type 'u 100'
      end
    end

    def test_until_method
      debug_code program do
        type 'u foo'
        assert_line_num 7
        type 'u bar'
        assert_line_num 8
        type 'c'
      end
    end
  end

  #
  # Tests that next/finish work for a deep call stack.
  # We use different logic for computing frame depth when the call stack is above/below 4096.
  #
  if false # RUBY_VERSION >= '3.0.0'
    # This test fails on slow machine or assertion enables Ruby, so skip it.
    class DeepCallstackTest < ConsoleTestCase
      def program
        <<~RUBY
           1| # target.rb
           2| def foo
           3|     "hello"
           4| end
           5|   
           6| def recursive(n,stop)
           7|   foo
           8|   return if n >= stop
           9| 
          10|   recursive(n + 1, stop)
          11| end
          12| 
          13| recursive(0, 4100)
          14| 
          15| "done"
        RUBY
      end
      
      def test_next
        debug_code(program) do
          type 'b 13'
          type 'c'
          assert_line_num 13
          type 'n'
          assert_line_num 15
          type 'kill!'
        end
      end
  
      def test_finish
        debug_code(program) do
          type 'b 13'
          type 'c'
          assert_line_num 13
          type 's'
          assert_line_num 7
          type 'fin'
          assert_line_num 11
          type 'kill!'
        end
      end
    end
  end
end

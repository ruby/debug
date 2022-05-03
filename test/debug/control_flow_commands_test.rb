# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  #
  # Test basic control flow commands.
  #
  class BasicControlFlowTest < TestCase
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

    def test_next_goes_to_the_corret_line_after_stepping
      debug_code(program) do
        type 'b 12'
        type 'c'
        assert_line_num 12
        type 's'
        assert_line_num 7
        type 'up'
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
        type 'q!'
      end
    end
  end

  #
  # Tests control flow commands with block.
  #
  class BlockControlFlowTest < TestCase
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

  class FinishControlFlowTest < TestCase
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
        type 'q!'
      end
    end

    def test_finish_0
      debug_code program do
        type 'b 8'
        type 'c'
        assert_line_num 8
        type 'fin 0'
        assert_line_text(/finish command with 0 does not make sense/)
        type 'q!'
      end
    end

    def test_finish_1
      debug_code program do
        type 'b 8'
        type 'c'
        assert_line_num 8
        type 'fin 1'
        assert_line_num 9
        type 'q!'
      end
    end

    def test_finish_2
      debug_code program do
        type 'b 8'
        type 'c'
        assert_line_num 8
        type 'fin 2'
        assert_line_num 6
        type 'q!'
      end
    end

    def test_finish_3
      debug_code program do
        type 'b 8'
        type 'c'
        assert_line_num 8
        type 'fin 3'
        assert_line_num 3
        type 'q!'
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
  class IfBlockControlFlowTest < TestCase
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
  class RescueControlFlowTest < TestCase
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
end

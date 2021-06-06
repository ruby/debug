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
        4| a += 1
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
        assert_line_num 4
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
        type 'next'
        assert_line_num 6
        type 'quit'
        type 'y'
      end
    end
  end
end

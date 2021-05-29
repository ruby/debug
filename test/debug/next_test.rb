# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  #
  # Tests basic stepping behaviour.
  #
  class BasicNextTest < TestCase
    def program
      <<~RUBY
        1| a = 1
        2| b = 2
        3| c = 3
      RUBY
    end

    def test_next_goes_to_the_next_line
      debug_code(program) do
        type 'next'
        assert_line_num 2
        type 'quit'
        type 'y'
      end
    end

    def test_n_goes_to_the_next_line
      debug_code(program) do
        type 'n'
        assert_line_num 2
        type 'quit'
        type 'y'
      end
    end
  end

  #
  # Tests next behaviour in rescue clause.
  #
  class NextRescueTest < TestCase
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

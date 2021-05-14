# frozen_string_literal: true

require 'test_helper'
require 'socket'

require_relative '../support/assertions'

module DEBUGGER__

  # Test basic stepping behaviour.

  class BasicSteppingTest < TestCase
    def program
      strip_line_numbers <<-RUBY
         1:  require 'debug/session'
         2:  DEBUGGER__.console
         3:  module DEBUGGER__
         4:    #
         5:    # Toy class to test stepping
         6:    #
         7:    class #{example_class}
         8:      def self.add_four(num)
         9:        num += 4
        10:        num
        11:      end
        12:    end
        13:
        14:    res = #{example_class}.add_four(7)
        15:
        16:    res + 1
        17:  end
      RUBY
    end

    def test_step_goes_to_the_next_statement
      debug_code(program) do
        enter "step"
        assertion 7
        enter "quit"
      end
    end

    def test_s_goes_to_the_next_statement
      debug_code(program) do
        enter "s"
        assertion 7
        enter "quit"
      end
    end
  end

  # Tests step/next more than one.

  class MoreThanOneStepTest < TestCase
    def program
      strip_line_numbers <<-RUBY
         1:  require 'debug/session'
         2:  DEBUGGER__.console
         3:  module DEBUGGER__
         4:    #
         5:    # Toy class to test advanced stepping.
         6:    #
         7:    class #{example_class}
         8:      def self.add_three(num)
         9:        2.times do
        10:          num += 1
        11:        end
        12:
        13:        num *= 2
        14:        num
        15:      end
        16:    end
        17:
        18:    res = #{example_class}.add_three(7)
        19:
        20:    res
        21:  end
      RUBY
    end

    def test_step_steps_into_blocks
      debug_code(program) do
        enter "step"
        assertion 7
        enter "step"
        assertion 8
        enter "step"
        assertion 18
        enter "quit"
      end
    end
  end
end

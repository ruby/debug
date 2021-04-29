# frozen_string_literal: true

require 'test_helper'
require 'socket'

module DEBUGGER__
  #
  # Test basic stepping behaviour.
  #
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
      enter 'step'

      debug_code(program) { assert_equal 8, current_frame.location.lineno }
    end

    def test_s_goes_to_the_next_statement
      enter 's'

      debug_code(program) { assert_equal 8, current_frame.location.lineno }
    end
  end
end

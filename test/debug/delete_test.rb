# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class Deletetest < TestCase
    def program
      <<~RUBY
        1| a=1
        1| b=2
        2| c=3
        3| d=4
      RUBY
    end

    def test_delete_deletes_all_breakpoints_by_default
      debug_code(program) do
        type "break 2"
        type "break 3"

        type "delete"
        type "y" # confirm deletion

        type "continue"
      end
    end

    def test_delete_deletes_a_specific_breakpoint
      debug_code(program) do
        type "break 2"
        type "break 3"

        type "delete 0"

        type "continue"
        assert_line_num(3)
        type "q!"
      end
    end

    def test_delete_keeps_current_breakpoints_if_not_confirmed
      debug_code(program) do
        type 'b 2'
        assert_debugger_out(/\#0  BP \- Line  .*/)
        type 'b 3'
        assert_debugger_out(/\#1  BP \- Line  .*/)
        type 'del'
        assert_debugger_out([
          /\#0  BP \- Line  .*/,
          /\#1  BP \- Line  .*/,
          /Remove all breakpoints\? \[y\/N\]/
        ])
        type 'n' # confirmation
        type 'b'
        assert_debugger_out([
          /\#0  BP \- Line  .*/,
          /\#1  BP \- Line  .*/
        ])
        type 'q!'
      end
    end
  end
end

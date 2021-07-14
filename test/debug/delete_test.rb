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
  end
end

# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class WhereamiTest < ConsoleTestCase
    def program
      <<~RUBY
         1| a = 1
         2| a = 1
         3| a = 1
         4| a = 1
         5| a = 1
         6| a = 1
         7| a = 1
         8| a = 1
         9| a = 1
        10| a = 1
        11| b = 1
        12| b = 1
        13| b = 1
        14| b = 1
        15| b = 1
        16| b = 1
        17| b = 1
        18| b = 1
        19| b = 1
        20| b = 1
        21| c = 1
      RUBY
    end

    def test_whereami_displays_current_frames_code
      debug_code(program) do
        type "list"
        type "list"

        # after 2 list commands, we should advance to the next 10 lines and not able to see the current frame's source
        assert_no_line_text(/=>   1\| a = 1/)
        assert_line_text(/b = 1/)

        type "whereami"

        # with whereami, we should see the current frame's source but have no visual outside the closest 10 lines
        assert_no_line_text(/b = 1/)
        assert_line_text(/=>   1\| a = 1/)

        type "list"

        # list command should work as normal after whereami is executed
        assert_no_line_text(/b = 1/)
        assert_line_text(/c = 1/)

        type "continue"
      end
    end
  end
end

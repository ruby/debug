# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class WhereamiTest < ConsoleTestCase
    def program
      <<~RUBY
         1| a = 1
         2| b = 1
         3| c = 1
         4| d = 1
         5| e = 1
         6| f = 1
         7| g = 1
         8| h = 1
         9| i = 1
        10| j = 1
        11| k = 1
        12| l = 1
        13| m = 1
        14| n = 1
        15| o = 1
        16| p = 1
        17| q = 1
        18| r = 1
        19| s = 1
        20| t = 1
        21| u = 1
      RUBY
    end

    def test_whereami_displays_current_frames_code
      debug_code(program) do
        type "list"
        type "list"

        # after 2 list commands, we should advance to the next 10 lines and not able to see the current frame's source
        assert_no_line_text(/=>   10\| j = 1/)
        assert_line_text(/k = 1/)

        type "whereami"

        # with whereami, we should see the current frame's source but have no visual outside the closest 10 lines
        assert_no_line_text(/k = 1/)
        assert_line_text(/=>   1\| a = 1/)

        type "list"

        # list command should work as normal after whereami is executed
        assert_no_line_text(/t = 1/)
        assert_line_text(/u = 1/)

        type "continue"
      end
    end

    def test_whereami_n_argument_removes_line_numbers
      debug_code(program) do
        type "whereami"

        assert_line_text([
         /1\| a = 1/,
         /2\| b = 1/,
         /3\| c = 1/,
         /4\| d = 1/,
         /5\| e = 1/,
         /6\| f = 1/,
         /7\| g = 1/,
         /8\| h = 1/,
         /9\| i = 1/,
         /10\| j = 1/
        ])

        type "whereami -n"

        # with -n there should be no line markers at all
        assert_no_line_text(/\|/)
        assert_line_text([
         /a = 1/,
         /b = 1/,
         /c = 1/,
         /d = 1/,
         /e = 1/,
         /f = 1/,
         /g = 1/,
         /h = 1/,
         /i = 1/,
         /j = 1/
        ])


        # whereami should work as normal again
        type "whereami"

        assert_line_text([
         /1\| a = 1/,
         /2\| b = 1/,
         /3\| c = 1/,
         /4\| d = 1/,
         /5\| e = 1/,
         /6\| f = 1/,
         /7\| g = 1/,
         /8\| h = 1/,
         /9\| i = 1/,
         /10\| j = 1/
        ])

        type "continue"
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class DisplayTest < ConsoleTestCase
    def program
      <<~RUBY
     1| a = 1
     2| b = 2
     3| binding.break
     4| __END__
      RUBY
    end

    def test_display_displays_expressions_when_the_program_stopps
      debug_code(program) do
        type "display a"
        assert_line_text(/0: a =/)
        type "display b"
        assert_line_text(/0: a = /)
        assert_line_text(/1: b = /)
        type "continue"
        assert_line_text(/0: a = 1/)
        assert_line_text(/1: b = 2/)

        type 'kill!'
      end
    end

    def test_display_without_expression_lists_display_settings
      debug_code(program) do
        type "display a"
        type "display b"
        type "display"
        assert_line_text(/0: a = /)
        assert_line_text(/1: b = /)

        type 'kill!'
      end
    end

    def test_undisplay_deletes_a_given_display_setting
      debug_code(program) do
        type "display a"
        type "undisplay 0"
        type "y"
        type "continue"
        assert_no_line_text(/0: a =/)

        type 'kill!'
      end
    end

    def test_undisplay_without_expression_deletes_all_display_settings
      debug_code(program) do
        type "display a"
        type "display b"
        type "undisplay"
        type "y"
        assert_no_line_text(/0: a = /)
        assert_no_line_text(/1: b = /)

        type 'kill!'
      end
    end
  end
end

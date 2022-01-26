# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class TUITest < TestCase
    def program
      <<~RUBY
     1| def foo(num)
     2|   num
     3| end
     4| a = 100
     5| b = 250
     6|
     7| binding.b
     8| foo(a + b)
      RUBY
    end

    def test_tui_activation
      debug_code(program, remote: false) do
        type "c"
        type "tui"
        assert_line_text([
          /%self = main/,
          /a = 100/
        ])
        type "s"
        type "s"
        assert_line_text(/num = 350/)
        type "c"
      end
    end

    def test_tui_activation_with_option
      debug_code(program, remote: false) do
        type "c"
        type "tui on src"
        assert_no_line_text(/%self = main/)
        assert_line_text(/=>   7| binding.b/)
        type "c"
      end

      debug_code(program, remote: false) do
        type "c"
        type "tui on foo"
        assert_line_text(/foo is not a supported TUI type/)
        type "c"
      end
    end

    def test_tui_deactivation
      debug_code(program, remote: false) do
        type "c"
        type "tui"
        assert_line_text([
          /%self = main/,
          /a = 100/
        ])
        type "tui off"
        type "s"
        type "s"
        assert_no_line_text(/num = 350/)
        type "c"
      end
    end
  end
end

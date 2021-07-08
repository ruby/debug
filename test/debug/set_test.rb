# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class SetTest < TestCase
    def program
      <<~RUBY
        1| def foo
        1|   bar
        2| end
        3| def bar
        4|   p :bar
        5| end
        6| foo
      RUBY
    end

    def test_set_show
      debug_code(program) do
        type 'set'
        # show all configurations with descriptions
        assert_line_text([
          /show_src_lines = \(default\)/,
          /show_frames = \(default\)/
        ])
        # only show this configuratio
        type 'set show_frames'
        assert_line_text([
          /show_frames = \(default\)/
        ])
        type 'q!'
      end
    end

    def test_set_show_frames
      debug_code(program) do
        type 'set show_frames=1'
        assert_line_text([
          /show_frames = 1/
        ])
        type 'b 5'
        type 'c'
        assert_line_num 5
        # only show 1 frame, and 2 frames are left.
        assert_line_text([
          /  # and 2 frames \(use `bt' command for all frames\)/,
        ])
        type 'q!'
      end
    end
  end
end

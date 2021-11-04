# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class FrameControlTest < TestCase
    def program
      <<~RUBY
     1| class Foo
     2|   def bar
     3|     baz
     4|   end
     5|
     6|   def baz
     7|     10
     8|   end
     9| end
    10|
    11| Foo.new.bar
      RUBY
    end

    def test_frame_prints_the_current_frame
      debug_code(program) do
        type 'b 7'
        type 'continue'

        type 'frame'
        assert_debugger_out(/Foo#baz at/)
        type 'q!'
      end
    end

    def test_up_moves_up_one_frame
      debug_code(program) do
        type 'b 7'
        type 'continue'

        type 'frame'
        assert_debugger_out(/Foo#baz at/)
        type 'up'
        assert_debugger_out(/Foo#bar at/)
        type 'up'
        assert_debugger_out(/<main> at/)
        type 'frame'
        assert_debugger_out(/<main> at/)
        type 'q!'
      end
    end

    def test_down_moves_down_one_frame
      debug_code(program) do
        type 'b 7'
        type 'continue'

        type 'up'
        assert_debugger_out(/Foo#bar at/)
        type 'up'
        assert_debugger_out(/<main> at/)
        type 'down'
        assert_debugger_out(/Foo#bar at/)
        type 'down'
        assert_debugger_out(/Foo#baz at/)
        type 'q!'
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class QuitTest < TestCase
    def program
      <<~RUBY
        1| a=1
      RUBY
    end

    def test_quit_quits_debugger_process_if_confirmed
      debug_code(program) do
        type 'q'
        assert_line_text(/Really quit\? \[Y\/n\]/)
        type 'y'
        assert_finish
      end
    end

    def test_quit_does_not_quit_debugger_process_if_not_confirmed
      debug_code(program) do
        type 'q'
        assert_line_text(/Really quit\? \[Y\/n\]/)
        type 'n'
        type 'q!'
        assert_finish
      end
    end

    def test_quit_with_exclamation_mark_quits_immediately_debugger_process
      debug_code(program) do
        type 'q!'
        assert_finish
      end
    end
  end
end

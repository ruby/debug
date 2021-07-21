# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class KillTest < TestCase
    def program
      <<~RUBY
        1| a = 1
      RUBY
    end

    def test_kill_kills_the_debugger_process_if_confirmed
      debug_code(program) do
        type 'kill'
        assert_line_text(/Really kill\? \[Y\/n\]/)
        type 'y'
      end
    end

    def test_kill_does_not_kill_the_debugger_process_if_not_confirmed
      debug_code(program) do
        type 'kill'
        assert_line_text(/Really kill\? \[Y\/n\]/)
        type 'n'
        type 'q!'
      end
    end

    def test_kill_with_exclamation_mark_kills_the_debugger_process_immediately
      debug_code(program) do
        type "kill!"
      end
    end
  end
end

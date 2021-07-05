# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class KillTest < TestCase
    def program
      <<~RUBY
      1| a = 1
      RUBY
    end

    def test_kill_kills_the_debugger_process_after_confirmation
      debug_code(program) do
        type "kill"
        type "y"
      end
    end

    def test_kill_with_exclamation_mark_kills_the_debugger_process_immediately
      debug_code(program) do
        type "kill!"
      end
    end
  end
end

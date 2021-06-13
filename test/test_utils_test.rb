# frozen_string_literal: true

require_relative 'support/test_case'

module DEBUGGER__
  class PseudoTerminalTest < TestCase
    def program
      <<~RUBY
        a = 1
      RUBY
    end

    def test_the_test_fails_when_debugger_exits_early
      assert_raise_message(/expect all commands\/assertions to be executed/) do
        debug_code(program) do
          type 'continue'
          type 'foo'
        end
      end
    end
  end
end

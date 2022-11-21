# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class HelpTest < ConsoleTestCase
    def program
      <<~RUBY
      1| a = 1
      RUBY
    end

    def test_help_prints_all_help_messages_by_default
      debug_code(program) do
        type "help"
        assert_line_text(
          [
            /### Breakpoint/,
            /Show all breakpoints/,
            /### Frame control/
          ]
        )
        type "continue"
      end
    end

    def test_help_only_prints_given_command_when_specified
      debug_code(program) do
        type "help break"
        assert_line_text(/Show all breakpoints/)
        assert_no_line_text(/### Frame control/)
        type "continue"
      end
    end

    def test_help_with_undefined_command_shows_an_error
      debug_code(program) do
        type 'help foo'
        assert_line_text(/not found: foo/)
        type 'kill!'
      end
    end
  end
end

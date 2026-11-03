# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class QuitTest < ConsoleTestCase
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
      end
    end

    def test_quit_does_not_quit_debugger_process_if_not_confirmed
      debug_code(program) do
        type 'q'
        assert_line_text(/Really quit\? \[Y\/n\]/)
        type 'n'
        type 'kill!'
      end
    end

    def test_quit_with_exclamation_mark_quits_immediately_debugger_process
      debug_code(program) do
        type 'q!'
      end
    end

    # The prompt hits EOF, which sends `quit`, and its confirmation can't be
    # read: as when Reline reads an exhausted STDIN while $stdin is closed.
    def test_quit_on_eof_quits_debugger_process_if_stdin_is_unreadable
      debug_code(<<~RUBY, remote: false) do
        1| $stdin = Object.new
        2| def $stdin.gets
        3|   (@eof = !@eof) ? nil : raise(IOError, 'closed stream')
        4| end
        5| a=1
      RUBY
        type 'b 5'
        type 'c'
        # never read: the debugger reads the fake $stdin
        type 'q'
        type 'y'
      end
    end
  end
end

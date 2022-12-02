# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class DaemonTest < ConsoleTestCase
    def program
      # Ignore SIGHUP since the test debuggee receives SIGHUP after Process.daemon.
      # When manualy debugging a daemon, it doesn't receive SIGHUP.
      # I don't know why.
      <<~'RUBY'
        1| trap(:HUP, 'IGNORE')
        2| puts 'Daemon starting'
        3| Process.daemon
        4| puts 'Daemon started'
      RUBY
    end

    def test_daemon
      # The program can't be debugged locally since the parent process exits when Process.daemon is called.
      debug_code program, remote: :remote_only do
        type 'b 3'
        type 'c'
        assert_line_num 3
        type 'b 4'
        type 'c'
        assert_line_num 4
        type 'c'
      end
    end
  end
end

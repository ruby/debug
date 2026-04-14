# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class WellKnownLockConsoleTest < ConsoleTestCase

    # Single-process debugging is unaffected by the well-known lock.
    def test_single_process_unaffected
      code = <<~RUBY
        1| require "debug"
        2| DEBUGGER__.start
        3| a = 1
        4| binding.break
        5| b = 2
      RUBY

      run_ruby(code) do
        assert_line_num 3
        type 'c'
        assert_line_num 4
        type 'c'
      end
    end

    # The well-known lock is skipped when MultiProcessGroup is active
    # (fork_mode: :both via rdbg).
    def test_fork_mode_both_uses_process_group_not_wk_lock
      code = <<~RUBY
        1| pid = fork do
        2|   sleep 0.5
        3|   a = 1
        4| end
        5| Process.waitpid pid
      RUBY

      debug_code(code) do
        type 'b 3'
        type 'c'
        assert_line_num 3
        type 'c'
      end
    end

    # Independent workers that load the debugger after fork are serialized
    # by the well-known lock. Each worker enters the debugger in sequence.
    def test_independent_workers_serialized
      code = <<~RUBY
        1| 2.times do |i|
        2|   fork do
        3|     require "debug"
        4|     DEBUGGER__.start(nonstop: true)
        5|     sleep 1
        6|     debugger
        7|     $stdout.puts "worker_\#{i}_done"
        8|   end
        9| end
       10| Process.waitall
      RUBY

      run_ruby(code) do
        assert_line_num 6
        type 'c'
        assert_line_num 6
        type 'c'
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class ForkBpSyncTest < ConsoleTestCase

    # Breakpoint set in parent AFTER fork is synced to child.
    # The child uses binding.break as a sync checkpoint -- when it enters
    # subsession there, bp_sync_check fires and picks up the new bp.
    def test_bp_set_after_fork_reaches_child
      code = <<~RUBY
        1| pid = fork do
        2|   sleep 2
        3|   binding.break      # sync checkpoint
        4|   a = 1              # bp target (set from parent after fork)
        5| end
        6| sleep 0.1
        7| binding.break        # parent stops here after fork
        8| Process.waitpid pid
      RUBY

      debug_code(code) do
        type 'c'
        assert_line_num 7
        type 'b 4'            # set bp AFTER fork
        type 'c'              # parent continues, bp_sync_publish writes to file
        assert_line_num 3     # child at sync checkpoint
        type 'c'              # child continues, hits synced bp
        assert_line_num 4
        type 'c'
      end
    end

    # Breakpoint deleted in parent after fork is removed from child.
    # Child inherits bp via COW, but parent deletes it and publishes.
    # When child syncs at its binding.break, the bp is reconciled away.
    def test_bp_deleted_after_fork_removed_from_child
      code = <<~RUBY
        1| pid = fork do
        2|   sleep 2
        3|   binding.break      # sync checkpoint
        4|   a = 1              # bp was inherited, then deleted via sync
        5|   binding.break      # child should stop here instead
        6| end
        7| sleep 0.1
        8| binding.break        # parent stops here
        9| Process.waitpid pid
      RUBY

      debug_code(code) do
        type 'b 4'            # set bp (will be inherited by child via COW)
        type 'c'
        assert_line_num 8
        type 'del 0'          # delete bp in parent
        type 'c'              # parent continues, bp_sync_publish (empty set)
        assert_line_num 3     # child at sync checkpoint
        type 'c'              # child continues, line 4 bp was removed by sync
        assert_line_num 5     # child skipped line 4
        type 'c'
      end
    end

    # Catch breakpoint syncs to child process.
    def test_catch_bp_sync_after_fork
      code = <<~RUBY
        1| pid = fork do
        2|   sleep 2
        3|   binding.break        # sync checkpoint
        4|   raise "test_error"
        5| rescue
        6|   binding.break        # child stops after rescue
        7| end
        8| sleep 0.5
        9| binding.break
       10| Process.waitpid pid
      RUBY

      debug_code(code) do
        type 'c'
        assert_line_num 9
        type 'catch RuntimeError' # set catch bp after fork
        type 'c'                  # parent continues, publish
        assert_line_num 3         # child at sync checkpoint
        type 'c'
        assert_line_num 4         # catch bp fires
        type 'c'
        assert_line_num 6         # child at rescue binding.break
        type 'c'
      end
    end

    # Breakpoints set before fork work in child (inherited via COW + sync).
    # Regression test that sync doesn't break the existing behavior.
    def test_bp_before_fork_works_in_child
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

    # Stress test with multiple children and binding.break.
    # Regression test that fork_mode: :both behavior isn't broken by sync.
    def test_bp_sync_stress
      code = <<~RUBY
        1| pids = 3.times.map do
        2|   fork do
        3|     sleep 1
        4|     2.times do
        5|       binding.break
        6|     end
        7|   end
        8| end
        9| sleep 0.1
       10| binding.break
       11| pids.each { |pid| Process.waitpid pid rescue nil }
      RUBY

      debug_code(code) do
        type 'c'
        assert_line_num 10
        type 'c'
        # 3 children x 2 iterations = 6 stops at line 5
        6.times do
          assert_line_num 5
          type 'c'
        end
      end
    end
  end
end

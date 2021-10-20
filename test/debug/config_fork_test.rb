# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  module ForkTestTemplate
    def program
      <<~RUBY
         1| #{fork_method} do
         2|   binding.b do: 'p :child_enter'
         3|   a = 1
         4|   b = 2
         5|   c = 3
         6|   binding.b do: 'p :child_leave'
         7| end
         8| sleep 0.5
         9| binding.b do: 'p :parent_enter'
        10| a = 1
        11| b = 2
        12| c = 3
        13| binding.b do: 'p :parent_leave'
      RUBY
    end

    def test_default_case
      debug_code(program) do
        # type 'config fork_mode = both' # default
        type 'b 5'
        type 'b 10'
        type 'c'
        assert_line_num 5
        # assert_line_text([/DEBUGGER: Detaching after fork from parent process \d+/,]) # TODO
        assert_line_text([
          # /DEBUGGER: Attaching after process \d+ fork to child process \d+/, # TODO
          /:child_enter/,
        ])
        type 'c' # continue 5
        assert_line_num 10
        type 'c' # continue 10
      end
    end

    def test_both_case
      debug_code(program) do
        type 'config fork_mode = both' # default
        type 'b 5'
        type 'b 10'
        type 'c'
        assert_line_num 5
        # assert_line_text([/DEBUGGER: Detaching after fork from parent process \d+/,]) # TODO
        assert_line_text([
          # /DEBUGGER: Attaching after process \d+ fork to child process \d+/, # TODO
          /:child_enter/,
        ])
        type 'c' # continue 5
        assert_line_num 10
        type 'c' # continue 10
      end
    end

    PN = 2
    LN = 2

    def test_both_stress
      code = <<~RUBY
       1| $0 = 'P  '; start_tm = Time.now; ps = #{PN}.times.map do |i|
       2|  fork do
       3|    $0 = "c\#{i} "
       4|    #{LN}.times{
       5|      binding.break
       6|    }
       7|   end
       8| end
       9| begin
      10|   ps.each{|pid| Process.waitpid pid; p finished_pid: pid}
      11| rescue Errno::ECHILD
      12| end
      13| p(waited: ps, time: (Time.now - start_tm)); binding.break
      RUBY

      debug_code code do
        type 'c' # first
        PN.times{
          LN.times{
            assert_line_num 5
            type 'c'
          }
        }
        assert_line_num 13
        type 'c'
      end
    end

    def test_child_case
      debug_code(program) do
        type 'config fork_mode = child'
        type 'b 5'
        type 'b 10'
        type 'c'
        assert_line_num 5
        # assert_line_text([/DEBUGGER: Detaching after fork from parent process \d+/,]) # TODO
        assert_line_text([
          # /DEBUGGER: Attaching after process \d+ fork to child process \d+/, # TODO
          /:child_enter/,
        ])
        type 'c'
      end
    end

    def test_parent_case
      debug_code(program) do
        type 'config parent_on_fork = true'
        type 'b 5'
        type 'b 10'
        type 'c'
        assert_line_num 10
        assert_line_text([
          # /DEBUGGER: Detaching after fork from child process \d+/, # TODO: puts on debug console
          /:parent_leave/
        ])
        type 'c'
      end
    end
  end

  class ConfigParentOnForkTest < TestCase
    include ForkTestTemplate
    def fork_method
      'fork'
    end
  end

  class ConfigParentOnForkWithProcessForkTest < TestCase
    include ForkTestTemplate
    def fork_method
      'Process.fork'
    end
  end

  class ConfigParentOnForkWithKernelForkTest < TestCase
    include ForkTestTemplate
    def fork_method
      'Kernel.fork'
    end
  end
end

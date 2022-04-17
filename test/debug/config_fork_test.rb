# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  module ForkWithBlock
    def program
      <<~RUBY
         1| pid = #{fork_method} do
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
        14| Process.waitpid pid
      RUBY
    end
  end

  module ForkWithoutBlock
    def program
      <<~RUBY
         1| if !(pid = #{fork_method})
         2|   binding.b do: 'p :child_enter'
         3|   a = 1
         4|   b = 2
         5|   c = 3
         6|   binding.b do: 'p :child_leave'
         7| else # parent
         8|   sleep 0.5
         9|   binding.b do: 'p :parent_enter'
        10|   a = 1
        11|   b = 2
        12|   c = 3
        13|   binding.b do: 'p :parent_leave'
        14|   Process.waitpid pid
        15| end
      RUBY
    end
  end

  module ForkTestTemplate
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

  # matrix
  [ForkWithBlock, ForkWithoutBlock].each.with_index{|program, i|
    ['fork', 'Process.fork', 'Kernel.fork'].each{|fork_method|
      c = Class.new TestCase do
        include ForkTestTemplate
        include program
        define_method :fork_method do
          fork_method
        end
      end

      const_set "Fork_#{fork_method.tr('.', '_')}_#{i}", c
    }
  }

  class NestedForkTest < TestCase
    def program
      <<~RUBY
        1| DEBUGGER__::CONFIG[:fork_mode] = :parent
        2| pid1 = fork do
        3|   puts 'parent forked.'
        4|   pid2 = fork do
        5|      puts 'child forked.'
        6|   end
        7|   Process.waitpid(pid2)
        8| end
        9| Process.waitpid(pid1)
      RUBY
    end

    def test_nested_fork
      debug_code program do
        type 'b 9'
        type 'c'
        assert_line_num 9
        type 'c'
      end
    end
  end
end

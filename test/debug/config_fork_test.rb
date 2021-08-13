# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class ConfigParentOnForkTest < TestCase
    def program
      <<~RUBY
         1| fork do
         2|   binding.b do: 'p :child_enter'
         3|   a = 1
         4|   b = 2
         5|   c = 3
         6|   binding.b do: 'p :child_leave'
         7| end
         8| 
         9| binding.b do: 'p :parent_enter'
        10| a = 1
        11| b = 2
        12| c = 3
        13| binding.b do: 'p :parent_leave'
      RUBY
    end

    def test_child_case
      debug_code(program) do
        type 'b 5'
        type 'b 10'
        type 'c'
        assert_line_num 5
        assert_line_text([/DEBUGGER: Detaching after fork from parent process \d+/,])
        assert_line_text([
          /DEBUGGER: Attaching after process \d+ fork to child process \d+/,
          /:child_enter/,
        ])
        type 'c'
      end
    end

    def test_child_case_process_fork
      debug_code(program.sub('fork', 'Process.fork')) do
        type 'b 5'
        type 'b 10'
        type 'c'
        assert_line_num 5
        assert_line_text([/DEBUGGER: Detaching after fork from parent process \d+/,])
        assert_line_text([
          /DEBUGGER: Attaching after process \d+ fork to child process \d+/,
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
          /DEBUGGER: Detaching after fork from child process \d+/,
        ])
        type 'c'
      end
    end
  end
end

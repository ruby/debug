# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class DebugCommandOptionTest < TestCase
    def program
      <<~RUBY
      1| raise "foo"
      RUBY
    end

    def test_debug_command_is_executed
      run_rdbg(program, options: "-e 'catch RuntimeError'") do
        type "c"
        assert_line_text(/Stop by #0  BP - Catch  "RuntimeError"/)
        type "q!"
      end
    end
  end
end

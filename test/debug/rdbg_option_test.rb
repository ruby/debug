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

  class NonstopOptionTest < TestCase
    def program
      <<~RUBY
      1| a = "foo"
      2| binding.b
      RUBY
    end

    def test_debugger_doesnt_stop
      run_rdbg(program, options: "--nonstop") do
        type "a + 'bar'"
        assert_line_text(/foobar/)
        type "c"
      end
    end
  end
end

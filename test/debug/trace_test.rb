# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class TraceTest < TestCase
    def program
      <<~RUBY
     1| def foo
     2|   10
     3| end
     4|
     5| a = 1
     6| foo + a
     7|
     8| binding.break
     9| __END__
      RUBY
    end

    def test_trace_on_starts_tracing
      debug_code(program) do
        type "trace on"
        assert_line_text /unknown command: trace on/
        type "q!"
      end
    end
  end
end

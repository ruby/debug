# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class EvalTest < TestCase
    def program
      <<~RUBY
     1| a = "foo"
     2| b = "bar"
     3| c = 3
     4| __END__
      RUBY
    end

    def test_eval_evaluates_method_call
      debug_code(program) do
        type 'b 3'
        type 'continue'
        type 'e a.upcase!'
        type 'p a'
        assert_debugger_out(/"FOO"/)
        type 'q!'
      end
    end

    def test_eval_evaluates_computation_and_assignment
      debug_code(program) do
        type 'b 3'
        type 'continue'
        type 'e b = a + b'
        type 'p b'
        assert_debugger_out(/"foobar"/)
        type 'q!'
      end
    end
  end
end

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
        assert_line_text(/"FOO"/)
        type 'q!'
      end
    end

    def test_eval_evaluates_computation_and_assignment
      debug_code(program) do
        type 'b 3'
        type 'continue'
        type 'e b = a + b'
        type 'p b'
        assert_line_text(/"foobar"/)
        type 'q!'
      end
    end

    def test_eval_provides_helpful_message_when_called_without_expression
      debug_code(program) do
        type 'e'

        assert_line_text(
          [
            /eval error: you must provide an expression for the e\[val\] command/,
            /to evaluate variables named 'e' or 'eval', please use 'pp <var>' instead/
          ]
        )

        type 'q!'
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class EvalTest < ConsoleTestCase
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
        type 'kill!'
      end
    end

    def test_eval_evaluates_computation_and_assignment
      debug_code(program) do
        type 'b 3'
        type 'continue'
        type 'e b = a + b'
        type 'p b'
        assert_line_text(/"foobar"/)
        type 'kill!'
      end
    end
  end
end

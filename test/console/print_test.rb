# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class PrintTest < ConsoleTestCase
    def program
      <<~RUBY
      1| h = { foo: "bar" }
      2| binding.break
      RUBY
    end

    def test_p_prints_the_expression
      debug_code(program) do
        type "c"
        type "p h"
        assert_line_text({ foo: "bar" }.inspect)
        type "c"
      end
    end

    def test_pp_pretty_prints_the_expression
      debug_code(program) do
        type "c"
        type "pp h"
        assert_line_text({ foo: "bar" }.pretty_print_inspect)
        type "c"
      end
    end
  end

  class InspectionFailureTest < ConsoleTestCase
    def program
      <<~RUBY
     1| f = Object.new
     2| def f.inspect
     3|   raise "foo"
     4| end
     5| binding.b
      RUBY
    end

    def test_p_prints_the_expression
      debug_code(program) do
        type "c"
        type "p f"
        assert_line_text('#<RuntimeError: foo> rescued during inspection')
        type "c"
      end
    end

    def test_pp_pretty_prints_the_expression
      debug_code(program) do
        type "c"
        type "pp f"
        assert_line_text('#<RuntimeError: foo> rescued during inspection')
        type "c"
      end
    end
  end
end

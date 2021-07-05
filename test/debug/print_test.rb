# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class PrintTest < TestCase
    def program
      <<~RUBY
      1| h = { foo: "bar" }
      2| binding.bp
      RUBY
    end

    def test_p_prints_the_expression
      debug_code(program) do
        type "c"
        type "p h"
        assert_line_text('{:foo=>"bar"}')
        type "c"
      end
    end

    def test_pp_pretty_prints_the_expression
      debug_code(program) do
        type "c"
        type "pp h"
        assert_line_text([/\{:foo=>/, /"bar"\}/])
        type "c"
      end
    end
  end
end

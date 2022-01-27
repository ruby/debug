# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class TildeTest < TestCase
    def program
      <<~RUBY
     1| list = 128
     2| nil
     3| __END__
      RUBY
    end

    def test_tilde_evaluates_instructions
      debug_code(program) do
        type 'b 2'
        type 'continue'
        type 'p list'
        assert_line_text(/=> 128/)
        type '~ list = 256'
        type 'p list'
        assert_line_text(/=> 256/)
        type 'q!'
      end
    end
  end
end

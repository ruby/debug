# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class NestedBreakAtMethodsTest < TestCase
    def program
      <<~RUBY
       1| def foo a
       2|   b = a + 1  # break
       3| end
       4| x = 1        # break
       5| x = 2
       6| x = 3
      RUBY
    end

    def test_nested_break
      debug_code program do
        type 'break 2'
        type 'break 4'
        type 'c'
        assert_line_num 4
        type 'p foo(42)'

        if TracePoint.respond_to? :allow_reentry
          # nested break
          assert_line_num 2
          type 'p a'
          assert_line_text(/42/)
          type 'c'
        end

        # pop nested break
        assert_line_text(/43/)
        type 'c'
      end
    end
  end
end


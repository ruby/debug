# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class NestedBreakAtMethodsTest < ConsoleTestCase
    def program
      <<~RUBY
       1| def foo a
       2|   b = a + 1  # break
       3| end
       4| def bar
       5|   x = 1      # break
       6| end
       7| bar
       8| x = 2
      RUBY
    end

    def test_nested_break
      debug_code program do
        type 'break 2'
        type 'break 5'
        type 'c'
        assert_line_num 5

        type 'up'
        assert_line_text(/=>\#1/)

        type 'p foo(42)'

        if TracePoint.respond_to? :allow_reentry
          # nested break
          assert_line_num 2
          type 'p a'
          assert_line_text(/42/)
          type 'c'
          assert_line_num 7 # because restored `up` line
        end

        # pop nested break
        assert_line_text(/43/)

        type 'bt'
        assert_line_text(/=>\#1/)

        type 'c'
      end
    end

    def test_nested_break_bt
      debug_code program do
        type 'break 2'
        type 'break 5'
        type 'c'

        assert_line_num 5
        type 'p foo(42)'

        if TracePoint.respond_to? :allow_reentry
          # nested break
          assert_line_num 2
          type 'bt'
          assert_no_line_text 'thread_client.rb'
          type 'c'
        end

        type 'c'
      end
    end

    def test_multiple_nested_break
      debug_code program do
        type 'break 2'
        type 'break 5'
        type 'c'
        assert_line_num 5

        type 'p foo(42)'

        if TracePoint.respond_to? :allow_reentry
          # nested break
          assert_line_num 2
          type 'p foo(142)'
          type 'bt'
          assert_line_text(/\#7\s+<main>/) # TODO: can be changed

          type 'c'
          assert_line_text(/143/)

          type 'bt'
          assert_no_line_text(/\#9/)

          type 'c'
        end

        assert_line_text(/43/)
        type 'c'
      end
    end
  end
end


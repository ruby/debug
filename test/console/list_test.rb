# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class ListTest < ConsoleTestCase
    def program
      <<~RUBY
      1| p 1
      2| p 2
      3| p 3
      4| p 4
      5| p 5
      6| p 6
      7| p 7
      8| p 8
      9| p 9
      10| p 10
      11| p 11
      12| p 12
      13| p 13
      14| p 14
      15| p 15
      16| p 16
      17| p 17
      18| p 18
      19| p 19
      20| p 20
      21| p 21
      22| p 22
      23| p 23
      24| p 24
      25| p 25
      26| p 26
      27| p 27
      28| p 28
      29| p 29
      30| p 30
      RUBY
    end

    def test_list_only_lists_part_of_the_program
      debug_code(program) do
        type 'list'
        assert_line_text(/p 1/)
        assert_line_text(/p 10/)
        assert_no_line_text(/p 11/)

        type 'kill!'
      end
    end

    def test_list_only_lists_after_the_given_line
      debug_code(program) do
        type 'list 11'
        assert_no_line_text(/p 10/)
        assert_line_text(/p 11/)

        type 'kill!'
      end
    end

    def test_list_continues_automatically
      debug_code(program) do
        type 'list'
        assert_line_text(/p 10/)
        assert_no_line_text(/p 11/)

        type ""
        assert_line_text(/p 20/)
        assert_no_line_text(/p 10/)
        assert_no_line_text(/p 21/)

        type ""
        assert_line_text(/p 30/)
        assert_no_line_text(/p 20/)
        type 'kill!'
      end
    end
  end
end

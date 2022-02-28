# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class NextTest < TestCase
    PROGRAM = <<~RUBY
      1| module Foo
      2|   class Bar
      3|     def self.a
      4|       "hello"
      5|     end
      6|   end
      7|   Bar.a
      8|   bar = Bar.new
      9| end
    RUBY
    
    def test_next_goes_to_the_next_statement
      run_protocol_scenario PROGRAM do
        req_next
        assert_line_num 2
        req_next
        assert_line_num 3
        req_next
        assert_line_num 7
        req_next
        assert_line_num 8
        req_terminate_debuggee
      end
    end
  end
end

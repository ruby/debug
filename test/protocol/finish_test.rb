# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class FinishTest < TestCase
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

    def test_finish_leaves_from_the_method
      run_protocol_scenario PROGRAM do
        req_add_breakpoint 3
        req_continue
        assert_line_num 4
        req_finish
        assert_line_num 5
        req_terminate_debuggee
      end
    end
  end
end

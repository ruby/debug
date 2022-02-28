# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class StepBackTest < TestCase
    PROGRAM = <<~RUBY
       1| binding.b do: 'record on'
       2| 
       3| module Foo
       4|   class Bar
       5|     def self.a
       6|       "hello"
       7|     end
       8|   end
       9|   Bar.a
      10|   bar = Bar.new
      11| end
    RUBY
    
    def test_step_back_goes_back_to_the_previous_statement
      run_protocol_scenario PROGRAM, cdp: false do
        req_add_breakpoint 9
        req_continue
        req_step_back
        assert_line_num 9
        req_step_back
        assert_line_num 5
        req_step_back
        assert_line_num 4
        req_terminate_debuggee
      end
    end
  end
end

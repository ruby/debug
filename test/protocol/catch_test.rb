# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class CatchTest < TestCase
    PROGRAM = <<~RUBY
      1| module Foo
      2|   class Bar
      3|     def self.a
      4|       raise 'foo'
      5|     end
      6|   end
      7|   Bar.a
      8|   bar = Bar.new
      9| end
    RUBY

    def test_catch_stops_when_the_runtime_error_raised
      run_protocol_scenario PROGRAM do
        req_set_exception_breakpoints
        req_continue
        assert_line_num 4
        req_terminate_debuggee
      end
    end
  end
end

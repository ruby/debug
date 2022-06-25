# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__
  class DeleteTest < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| module Foo
      2|   class Bar
      3|     def self.a
      4|       'hello'
      5|     end
      6|   end
      7|   Bar.a
      8|   bar = Bar.new
      9| end
    RUBY

    def test_delete_deletes_specific_breakpoints
      run_protocol_scenario PROGRAM do
        req_add_breakpoint 3
        req_add_breakpoint 5
        req_add_breakpoint 8
        req_delete_breakpoint 0
        req_delete_breakpoint 0
        req_continue
        assert_line_num 8
        req_terminate_debuggee
      end
    end
  end
end

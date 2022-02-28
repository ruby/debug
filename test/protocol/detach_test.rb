# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class DetachTest < TestCase
    PROGRAM = <<~RUBY
       1| module Foo
       2|   class Bar
       3|     def self.a
       4|       "hello"
       5|     end
       6|   end
       7|   loop do
       8|     b = 1
       9|   end
      10|   Bar.a
      11|   bar = Bar.new
      12| end
    RUBY

    def test_detach_reattach_to_rdbg
      run_protocol_scenario PROGRAM do
        assert_reattach
        req_terminate_debuggee
      end
    end
  end
end

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

        assert_locals_result(
          [
            { name: "%self", value: "Foo", type: "Module" },
            { name: "bar", value: "nil", type: "NilClass" }
          ]
        )
        req_next
        assert_line_num 3

        assert_locals_result(
          [
            { name: "%self", value: "Foo::Bar", type: "Class" },
          ]
        )
        req_next
        assert_line_num 7

        assert_locals_result(
          [
            { name: "%self", value: "Foo", type: "Module" },
            { name: "bar", value: "nil", type: "NilClass" }
          ]
        )
        req_next
        assert_line_num 8

        assert_locals_result(
          [
            { name: "%self", value: "Foo", type: "Module" },
            { name: "bar", value: "nil", type: "NilClass" }
          ]
        )
        req_terminate_debuggee
      end
    end
  end
end

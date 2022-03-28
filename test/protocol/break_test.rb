# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class BreakTest1 < TestCase
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

    def test_break_stops_at_correct_place
      run_protocol_scenario PROGRAM do
        req_add_breakpoint 5
        req_continue
        assert_line_num 5

        assert_locals_result(
          [
            { name: "%self", value: "Foo::Bar", type: "Class" },
            { name: "_return", value: "hello", type: "String" }
          ]
        )

        req_add_breakpoint 9
        req_continue
        assert_line_num 9

        assert_locals_result(
          [
            { name: "%self", value: "Foo", type: "Module" },
            { name: "bar", value: /#<Foo::Bar/, type: "Foo::Bar" }
          ]
        )
        req_terminate_debuggee
      end
    end
  end

  class BreakTest2 < TestCase
    def program path
      <<~RUBY
        1| require_relative "#{path}"
        2| Foo.new.bar
      RUBY
    end

    def extra_file
      <<~RUBY
        class Foo
          def bar
            puts :hoge
            a = 1
            bar2
          end

          def bar2
            b = 1
          end
        end
      RUBY
    end

    def test_break_stops_at_the_extra_file
      with_extra_tempfile do |extra_file|
        run_protocol_scenario(program(extra_file.path), cdp: false) do
          req_next
          assert_line_num 2
          req_step
          assert_line_num 3
          req_add_breakpoint 8, path: extra_file.path
          req_continue
          assert_line_num 9
          req_terminate_debuggee
        end
      end
    end
  end
end

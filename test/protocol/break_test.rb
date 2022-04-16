# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__
  class BreakTest1 < ProtocolTestCase
    PROGRAM = <<~RUBY
     1| class Foo
     2|   def self.bar
     3|     "hello"
     4|   end
     5|
     6|   def baz
     7|     10
     8|   end
     9| end
    10|
    11| Foo.bar
    12| f = Foo.new
    13| f.baz
    RUBY

    def test_set_breakpoints_sets_line_breakpoints
      run_protocol_scenario PROGRAM do
        req_add_breakpoint 4
        req_continue
        assert_line_num 4

        assert_locals_result(
          [
            { name: "%self", value: "Foo", type: "Class" },
            { name: "_return", value: "hello", type: "String" }
          ]
        )

        req_add_breakpoint 13
        req_continue
        assert_line_num 13

        assert_locals_result(
          [
            { name: "%self", value: "main", type: "Object" },
            { name: "f", value: /#<Foo.*>/, type: "Foo" }
          ]
        )
        req_terminate_debuggee
      end
    end

    def test_set_function_breakpoints_sets_instance_method_breakpoints
      run_protocol_scenario PROGRAM, cdp: false do
        res_set_function_breakpoints([{ name: "Foo.bar" }])
        req_continue
        assert_line_num 3

        assert_locals_result(
          [
            { name: "%self", value: "Foo", type: "Class" }
          ]
        )

        req_continue
      end
    end

    def test_set_function_breakpoints_sets_class_method_breakpoints
      run_protocol_scenario PROGRAM, cdp: false do
        req_add_breakpoint 13
        req_continue
        assert_line_num 13

        res_set_function_breakpoints([{ name: "f.baz" }])
        req_continue

        assert_line_num 7

        req_terminate_debuggee
      end
    end

    def test_set_function_breakpoints_unsets_method_breakpoints
      run_protocol_scenario PROGRAM, cdp: false do
        res_set_function_breakpoints([{ name: "Foo::Bar.a" }])
        res_set_function_breakpoints([])
        req_continue
      end
    end
  end

  class BreakTest2 < ProtocolTestCase
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

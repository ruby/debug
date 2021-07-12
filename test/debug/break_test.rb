# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  #
  # Tests adding breakpoints to methods
  #
  class BreakAtMethodsTest < TestCase
    def program
      <<~RUBY
         1| module Foo
         2|   class Bar
         3|     def self.a
         4|       "hello"
         5|     end
         6|
         7|     def b(n)
         8|       2.times do
         9|         n
        10|       end
        11|     end
        12|   end
        13|   module Baz
        14|     def self.c
        15|       1
        16|     end
        17|   end
        18|   Bar.a
        19|   bar = Bar.new
        20|   bar.b(1)
        21|   Baz.c
        22| end
      RUBY
    end

    def test_break_with_namespaced_instance_method_stops_at_correct_place
      debug_code(program) do
        type 'break Foo::Bar#b'
        assert_line_text(/#0  BP - Method \(pending\)  Foo::Bar#b/)
        type 'continue'
        assert_line_num 8
        type 'quit!'
      end
    end

    def test_break_with_namespaced_class_method_stops_at_correct_place
      debug_code(program) do
        type 'break Foo::Bar.a'
        type 'continue'
        assert_line_num 4
        type 'quit!'
      end
    end

    def test_break_with_namespaced_module_method_stops_at_correct_place
      debug_code(program) do
        type 'break Foo::Baz.c'
        type 'continue'
        assert_line_num 15
        type 'quit!'
      end
    end

    def test_break_with_a_method_does_not_stop_at_blocks_in_the_method
      debug_code(program) do
        type 'break Foo::Bar#b'
        type 'continue'
        assert_line_num 8
        type 'break 9'
        type 'continue'
        assert_line_num 9
        type 'quit!'
      end
    end

    def test_debugger_rejects_duplicated_method_breakpoints
      debug_code(program) do
        type 'break Foo::Baz.c'
        type 'break Foo::Baz.c'
        assert_line_text(/duplicated breakpoint/)
        type 'continue'
        assert_line_num 15
        type 'continue'
      end
    end

    def test_break_command_isnt_repeatable
      debug_code(program) do
        type 'break Foo::Baz.c'
        type ''
        assert_no_line_text(/duplicated breakpoint/)
        type 'quit!'
      end
    end
  end

  class BreakAtCMethodsTest < TestCase
    def program
      <<~RUBY
        1| a = 1
        2|
        3| a.abs
      RUBY
    end

    def test_debugger_stops_when_the_c_method_is_called
      debug_code(program) do
        type 'b Integer#abs'
        type 'continue'

        if RUBY_VERSION.to_f >= 3.0
          assert_line_text('Integer#abs at <internal:')
        else
          # it doesn't show any source before Ruby 3.0
          assert_line_text('<main>')
        end

        type 'quit'
        type 'y'
      end
    end
  end

  #
  # Tests adding breakpoints to empty methods
  #
  class BreakAtEmptyMethodsTest < TestCase
    def program
      <<~RUBY
         1| module Foo
         2|   class Bar
         3|     def a
         4|     end
         5|
         6|     def b(n)
         7|
         8|     end
         9|     def self.c; end
        10|   end
        11|   bar = Bar.new
        12|   bar.a
        13|   bar.b(1)
        14|   Bar.c
        15| end
      RUBY
    end

    def test_break_with_instance_method_stops_at_correct_place_a
      debug_code(program) do
        type 'break Foo::Bar#a'
        type 'continue'
        assert_line_num 3
        type 'quit!'
      end
    end

    def test_break_with_instance_method_stops_at_correct_place_b
      # instance method #b has extra empty line intentionally
      # to test lineno 8 is not displayed.
      debug_code(program) do
        type 'break Foo::Bar#b'
        type 'continue'
        assert_line_num 6
        type 'quit!'
      end
    end

    def test_break_with_class_method_stops_at_correct_place
      debug_code(program) do
        type 'break Foo::Bar.c'
        type 'continue'
        assert_line_num 9
        type 'quit!'
      end
    end
  end

  #
  # Tests adding breakpoints to lines
  #
  class BreakAtLinesTest < TestCase
    def program
      <<~RUBY
         1| module Foo
         2|   class Bar
         3|     def self.a
         4|       "hello"
         5|     end
         6|
         7|     def b(n)
         8|       2.times do
         9|         n
        10|       end
        11|     end
        12|   end
        13|   module Baz
        14|     def self.c
        15|       d = 1
        16|     end
        17|   end
        18|   Bar.a
        19|   bar = Bar.new
        20|   bar.b(1)
        21|   Baz.c
        22| end
      RUBY
    end

    def test_stops_at_correct_place_when_breakpoint_set_in_a_regular_line
      debug_code(program) do
        type 'break 4'
        assert_line_text(/#0  BP - Line  .*\.rb:4 \(call\)/)
        type 'continue'
        assert_line_num 4
        type 'quit'
        type 'y'
      end
    end

    def test_stops_at_correct_place_when_breakpoint_set_in_empty_line
      debug_code(program) do
        type 'break 6'
        type 'continue'
        assert_line_num 7
        type 'quit'
        type 'y'
      end
    end

    def test_conditional_breakpoint_stops_for_repeated_iterations
      debug_code(program) do
        type 'break 9'
        type 'continue'
        assert_line_num 9
        type 'continue'
        assert_line_num 9
        type 'quit'
        type 'y'
      end
    end

    def test_conditional_breakpoint_stops_if_condition_is_true
      debug_code(program) do
        type 'break if: n == 1'
        assert_line_text(/#0  BP - Check  n == 1/)
        type 'continue'
        assert_line_num 8
        type 'quit'
        type 'y'
      end
    end

    def test_conditional_breakpoint_stops_at_specified_location_if_condition_is_true
      debug_code(program) do
        type 'break 16 if: d == 1'
        assert_line_text(/#0  BP - Line  .*\.rb:16 \(return\) if: d == 1/)
        type 'continue'
        assert_line_num 16
        type 'quit'
        type 'y'
      end
    end

    def test_debugger_rejects_duplicated_line_breakpoints
      debug_code(program) do
        type 'break 19'
        type 'break 18'
        type 'break 18'
        assert_line_text(/duplicated breakpoint:/)
        type 'continue'
        assert_line_num 18
        type 'continue'
        assert_line_num 19
        type 'quit!'
      end
    end
  end

  class DeleteTest < TestCase
    def program
      <<~RUBY
     1| a = 1
     2| b = 2
     3| c = 3
     4| d = 4
      RUBY
    end

    def test_delete_deletes_all_breakpoints_by_default
      debug_code(program) do
        type "break 2"
        type "break 3"

        type "delete"
        type "y" # confirm deletion

        type "continue"
      end
    end

    def test_delete_deletes_a_specific_breakpoint
      debug_code(program) do
        type "break 2"
        type "break 3"

        type "delete 0"

        type "continue"
        assert_line_num(3)
        type "q!"
      end
    end
  end
end

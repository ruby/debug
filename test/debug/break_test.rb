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
        type 'continue'
        assert_line_num 8
        type 'quit'
        type 'y'
      end
    end

    def test_break_with_namespaced_class_method_stops_at_correct_place
      debug_code(program) do
        type 'break Foo::Bar.a'
        type 'continue'
        assert_line_num 4
        type 'quit'
        type 'y'
      end
    end

    def test_break_with_namespaced_module_method_stops_at_correct_place
      debug_code(program) do
        type 'break Foo::Baz.c'
        type 'continue'
        assert_line_num 15
        type 'quit'
        type 'y'
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

    def test_break_with_instance_method_stops_at_correct_place_b
      # instance method #b has extra empty line intentionally
      # to test lineno 8 is not displayed.
      debug_code(program) do
        type 'break Foo::Bar#b'
        type 'continue'
        assert_line_num 6
        type 'quit'
        type 'y'
      end
    end

    def test_break_with_oneline_class_method_stops_at_correct_place
      debug_code(program) do
        type 'break Foo::Bar.c'
        type 'continue'
        assert_line_num 9
        type 'quit'
        type 'y'
      end
    end

    def test_break_with_instance_method_stops_at_correct_place_a
      debug_code(program) do
        type 'break Foo::Bar#a'
        type 'continue'
        assert_line_num 3
        type 'quit'
        type 'y'
      end
    end
  end

  #
  # Tests adding breakpoints to lines
  #
  class BreakAtLinesTest < TestCase
    def program
      <<~RUBY
        1| a = 1
        2| b = 2
        3| c = 3
      RUBY
    end

    def test_setting_breakpoint_sets_correct_fields
      debug_code(program) do
        type 'break 3'
        type 'continue'
        assert_line_num 3
        type 'quit'
        type 'y'
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  #
  # Tests adding breakpoints to methods
  #
  class BreakAtMethodsTest < TestCase
    def program
      <<~RUBY
        module Foo
          class Bar
            def self.a
              "hello"
            end

            def b(n)
              2.times do
                n
              end
            end
          end
          module Baz
            def self.c
              1
            end
          end
          Bar.a
          bar = Bar.new
          bar.b(1)
          Baz.c
        end
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
        module Foo
          class Bar
            def a
            end

            def b(n)

            end
            def self.c; end
          end
          bar = Bar.new
          bar.a
          bar.b(1)
          Bar.c
        end
      RUBY
    end

    def test_break_with_instance_method_stops_at_correct_place
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

    def test_break_with_instance_method_stops_at_correct_place
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
        a = 1
        b = 2
        c = 3
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

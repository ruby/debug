# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  #
  # Tests adding breakpoints to methods
  #
  class BreakAtMethodsTest < ConsoleTestCase
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
        type 'kill!'
      end
    end

    def test_break_with_namespaced_class_method_stops_at_correct_place
      debug_code(program) do
        type 'break Foo::Bar.a'
        type 'continue'
        assert_line_num 4
        type 'kill!'
      end
    end

    def test_break_with_namespaced_module_method_stops_at_correct_place
      debug_code(program) do
        type 'break Foo::Baz.c'
        type 'continue'
        assert_line_num 15
        type 'kill!'
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
        type 'kill!'
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
        type 'kill!'
      end
    end
  end

  class BreakAtClassMethodsTest < ConsoleTestCase
    def program
      <<~RUBY
     1| class A
     2|   def self.bar
     3|   end
     4| end
     5|
     6| class B < A
     7| end
     8|
     9| class C < A
    10| end
    11|
    12| binding.b
    13|
    14| B.bar
    15| binding.b
      RUBY
    end

    def test_debugger_stops_when_target_class_calls_the_parent_method
      debug_code(program) do
        type "c"
        type "b B.bar"
        type "c"
        assert_line_text(/Stop by #0  BP - Method  B.bar/)
        type "c"
        type "c"
      end
    end

    def test_debugger_doesnt_stop_when_other_class_calls_the_parent_method
      debug_code(program) do
        type "c"
        type "b C.bar"
        type "c"
        assert_no_line_text(/Stop by #0  BP - Method  C.bar/)
        type "c"
      end
    end
  end

  class BreakAtInstanceMethodsTest < ConsoleTestCase
    def program
      <<~RUBY
     1|  class A
     2|    def bar
     3|    end
     4|  end
     5|
     6|  class B < A
     7|  end
     8|
     9|  class C < A
    10| end
    11|
    12| b = B.new
    13| c = C.new
    14|
    15| binding.b
    16|
    17| b.bar
    18| binding.b
      RUBY
    end

    def test_debugger_stops_when_target_class_instance_calls_the_inherited_method
      debug_code(program) do
        type "c"
        type "b B#bar"
        type "c"
        assert_line_text(/Stop by #0  BP - Method  B#bar/)
        type "c"
        type "c"
      end
    end

    def test_debugger_doesnt_stop_when_other_class_instance_calls_the_inherited_method
      debug_code(program) do
        type "c"
        type "b C#bar"
        type "c"
        assert_no_line_text(/Stop by #0  BP - Method  C#bar/)
        type "c"
      end
    end

    def test_debugger_stops_when_target_instance_calls_the_inherited_method
      debug_code(program) do
        type "c"
        type "b b.bar"
        type "c"
        assert_line_text(/Stop by #0  BP - Method  b.bar/)
        type "c"
        type "c"
      end
    end

    def test_debugger_doesnt_stop_when_other_instance_calls_the_inherited_method
      debug_code(program) do
        type "c"
        type "b c.bar"
        type "c"
        assert_no_line_text(/Stop by #0  BP - Method  b.bar/)
        type "c"
      end
    end

    class PathOptionTest < ConsoleTestCase
      def extra_file
        <<~RUBY
        Foo.new.bar
        RUBY
      end

      def program(extra_file_path)
        <<~RUBY
         1| class Foo
         2|   def bar; end
         3| end
         4|
         5| Foo.new.bar
         6|
         7| load "#{extra_file_path}"
        RUBY
      end

      def test_break_only_stops_when_path_matches
        with_extra_tempfile("foohtml") do |extra_file|
          # exact path match should work in both Regexp and String form
          debug_code(program(extra_file.path)) do
            type "break Foo#bar path: /#{extra_file.path}/"
            type 'c'
            assert_line_text(/#{extra_file.path}/)
            type 'c'
          end

          debug_code(program(extra_file.path)) do
            type "break Foo#bar path: #{extra_file.path}"
            type 'c'
            assert_line_text(/#{extra_file.path}/)
            type 'c'
          end

          # special characters should be treated differently in Regexp/String form
          debug_code(program(extra_file.path)) do
            type "break Foo#bar path: /.html/"
            type 'c'
            assert_line_text(/#{extra_file.path}/)
            type 'c'
          end

          debug_code(program(extra_file.path)) do
            type "break Foo#bar path: .html"
            type 'c'
          end
        end
      end

      def test_the_path_option_supersede_skip_path_config
        # skips the extra_file's breakpoint
        with_extra_tempfile do |extra_file|
          debug_code(program(extra_file.path)) do
            type "config set skip_path /#{extra_file.path}/"
            type "break Foo#bar"
            type 'c'
            type 'up'
            assert_line_num(5) # from the main file
            type 'c'
          end
        end

        # ignores skip_path and stops at designated path
        with_extra_tempfile do |extra_file|
          debug_code(program(extra_file.path)) do
            type "config set skip_path /#{extra_file.path}/"
            type "break Foo#bar path: #{extra_file.path}"
            type 'c'
            type 'up'
            assert_line_num(1) # from the extra_file
            type 'c'
          end
        end
      end
    end
  end

  class BreakAtCMethodsTest < ConsoleTestCase
    def program
      <<~RUBY
     1| a = 1
     2|
     3| a.abs
     4| a.div(1)
     5| a.times { false }
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

    def test_debugger_passes_required_argument_correctly
      debug_code(program) do
        type 'b Integer#div'
        type 'continue'

        if RUBY_VERSION.to_f >= 3.0
          assert_line_text('Integer#div at')
        else
          # it doesn't show any source before Ruby 3.0
          assert_line_text('<main>')
        end

        type 'quit'
        type 'y'
      end
    end

    def test_debugger_passes_block_argument_correctly
      debug_code(program) do
        type 'b Integer#times'
        type 'continue'

        if RUBY_VERSION.to_f >= 3.0
          assert_line_text('Integer#times at')
        else
          # it doesn't show any source before Ruby 3.0
          assert_line_text('<main>')
        end

        type 'quit'
        type 'y'
      end
    end

    def test_break_C_method_with_singleton_method
      debug_code program do
        type 'b 1.abs'
        type 'c'
        assert_line_text(/:3\b/)
        type 'c'
      end
    end

    class PathOptionTest < ConsoleTestCase
      def extra_file
        <<~RUBY
        1.abs
        RUBY
      end

      def program(extra_file_path)
        <<~RUBY
        1| load "#{extra_file_path}"
        2| 1.abs
        RUBY
      end

      def test_break_only_stops_when_path_matches
        with_extra_tempfile do |extra_file|
          debug_code(program(extra_file.path)) do
            type "break Integer#abs path: #{extra_file.path}"
            type 'c'
            assert_line_text(/#{extra_file.path}/)
            type 'c'
          end
        end
      end
    end
  end

  class BreakAtCMethod2Test < ConsoleTestCase
    def program
      <<~RUBY
        1| binding.b(do: "b Array#each")
        2|
        3| result = ""
        4|
        5| [1, 2, 3].each do |i|
        6|   result += i.to_s
        7| end
        8|
        9| binding.b
      RUBY
    end

    def test_1629445385
      debug_code(program) do
        type 'c'
        assert_line_num 5
        type 'c'
        assert_line_num 9
        type 'c'
      end
    end
  end

  class BreakWithCommandTest < ConsoleTestCase
    def program
      <<~RUBY
     1| def foo
     2|   "foo"
     3| end
     4|
     5| s = "a"
     6|
     7| foo
     8|
     9| "for another bp to stop"
    10| __END__
      RUBY
    end

    def test_break_command_executes_pre_option_and_stops_with_line_bp
      debug_code(program) do
        type 'break 6 pre: p s*10'
        type 'c'
        assert_line_text(/aaaaaaaaaa/)
        type 'c'
      end
    end

    def test_break_command_executes_pre_option_and_stops_with_method_bp
      debug_code(program) do
        type 'break Object#foo pre: p "foobar"'
        type 'c'
        assert_line_text(/foobar/)
        type 'c'
      end
    end

    def test_break_command_executes_do_option_and_continues_with_line_bp
      debug_code(program) do
        type 'break 6 do: p s*10'
        type 'break 9'
        type 'c'
        assert_line_text(/aaaaaaaaaa/)
        type 'c'
      end
    end

    def test_break_command_executes_do_option_and_continues_with_method_bp
      debug_code(program) do
        type 'break Object#foo do: p "foobar"'
        type 'break 9'
        type 'c'
        assert_line_text(/foobar/)
        type 'c'
      end
    end

    def test_break_command_executes_do_option_and_continues_with_check_bp
      debug_code(program) do
        type 'break if: s.is_a?(String) do: p "foobar"'
        assert_line_text(/BP - Check  if: s\.is_a\?\(String\) do: p "foobar"/)
        type 'break 9'
        type 'c'
        assert_line_text(/foobar/)
        type 'c'
      end
    end
  end

  #
  # Tests adding breakpoints to empty methods
  #
  class BreakAtEmptyMethodsTest < ConsoleTestCase
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
        type 'kill!'
      end
    end

    def test_break_with_instance_method_stops_at_correct_place_b
      # instance method #b has extra empty line intentionally
      # to test lineno 8 is not displayed.
      debug_code(program) do
        type 'break Foo::Bar#b'
        type 'continue'
        assert_line_num 6
        type 'kill!'
      end
    end

    def test_break_with_class_method_stops_at_correct_place
      debug_code(program) do
        type 'break Foo::Bar.c'
        type 'continue'
        assert_line_num 9
        type 'kill!'
      end
    end
  end

  class MethodAddedTest < ConsoleTestCase
    def program_method_added
      <<~RUBY
         1| class C
         2|   def self.method_added mid
         3|     debugger
         4|   end
         5|   def foo
         6|   end
         5| end
         6| C.new.foo
      RUBY
    end

    def test_break_after_user_defined_method_added
      debug_code program_method_added do
        type 'b C#foo'
        type 'c'
        assert_line_num 3
        type 'c'
        assert_line_num 5
        type 'c'
      end
    end

    def program_singleton_method_added
      <<~RUBY
         1| class C
         2|   def self.singleton_method_added mid
         3|     super # Required. This is curent limitation for user-defined singleton_method_added method
         4|   end
         5|   def self.foo
         6|   end
         5| end
         6| C.foo
      RUBY
    end

    def test_break_after_user_defined_singleton_method_added
      debug_code program_singleton_method_added do
        type 'b C.foo'
        type 'c'
        assert_line_num 5
        type 'c'
      end
    end


  end

  #
  # Tests adding breakpoints to lines
  #
  class BreakAtLinesTest < ConsoleTestCase
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
        23| a = nil
      RUBY
    end

    def test_break_stops_at_correct_place_when_breakpoint_set_in_a_regular_line
      debug_code(program) do
        type 'break 4'
        assert_line_text(/#0  BP - Line  .*\.rb:4 \(call\)/)
        type 'continue'
        assert_line_num 4
        type 'quit'
        type 'y'
      end
    end

    def test_break_stops_at_correct_place_when_breakpoint_set_in_empty_line
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
        type 'kill!'
      end
    end

    def test_break_with_colon_between_file_and_line_stops_at_correct_place
      debug_code(program) do
        type "b #{temp_file_path}:4"
        assert_line_text(/\#0  BP \- Line  .*/)
        type 'c'
        assert_line_num 4
        type 'kill!'
      end
    end

    def test_break_with_space_between_file_and_line_stops_at_correct_place
      debug_code(program) do
        type "b #{temp_file_path} 9"
        assert_line_text(/\#0  BP \- Line  .*/)
        type 'c'
        assert_line_num 9
        type 'kill!'
      end
    end
  end

  class ConditionalBreakTest < ConsoleTestCase
    def program
      <<~RUBY
     1| a = 1
     2| a += 1
     3| a += 2
     4| a += 3
     5| a = 0
     6| a = 1
     7| a = 2
     8| a = 3
     9| binding.b
      RUBY
    end


    def test_conditional_breakpoint_stops_if_condition_is_true
      debug_code program do
        type 'break if: a == 4'
        assert_line_text(/#0  BP - Check  if: a == 4/)
        type 'c'
        assert_line_num 4
        type 'c'
        type 'c'
      end
    end

    def test_conditional_breakpoint_shows_error
      debug_code(program) do
        type 'break if: xyzzy'
        type 'c'
        assert_debuggee_line_text(/EVAL ERROR/)
        type 'c'
      end
    end

    def test_conditional_breakpoint_ignores_unchanged_true_condition
      debug_code(program) do
        type 'break if: a > 0'
        type 'c'
        assert_line_num(2) # stopped by line 1
        # the state remains fulfilled so the next 2 lines don't trigger stoppage
        type 'c'
        # line 5 changes the state. so the next true condition will stop the program again
        assert_line_num(7) # stopped by line 6
        type 'c'
        # the state remains fulfilled again, so the line 7 doesn't trigger stoppage
        assert_line_num(9)
        type 'c'
      end
    end

    class PathOptionTest < ConsoleTestCase
      def extra_file
        <<~RUBY
        a = 100
        b = 1
        _ = 0
        RUBY
      end

      def program(extra_file_path)
        <<~RUBY
       1| a = 200
       2| b = 1
       3| _ = 0
       4| load "#{extra_file_path}"
        RUBY
      end

      def test_conditional_breakpoint_only_stops_when_path_matches
        with_extra_tempfile do |extra_file|
          debug_code(program(extra_file.path)) do
            type "break if: b == 1 path: #{extra_file.path}"
            type 'c'
            type 'a + b'
            assert_line_text(/101/)
            type 'c'
          end
        end
      end

      def test_the_path_option_supersede_skip_path_config
        # skips the extra_file's breakpoint
        with_extra_tempfile do |extra_file|
          debug_code(program(extra_file.path)) do
            type "config set skip_path /#{extra_file.path}/"
            type "break if: b == 1"
            type 'c'
            type 'a + b'
            assert_line_num(3)
            assert_line_text(/201/)
            type 'c'
          end
        end

        # ignores skip_path and stops at designated path
        with_extra_tempfile do |extra_file|
          debug_code(program(extra_file.path)) do
            type "config set skip_path /#{extra_file.path}/"
            type "break if: b == 1 path: #{extra_file.path}"
            type 'c'
            type 'a + b'
            assert_line_text(/101/)
            type 'c'
          end
        end
      end
    end
  end

  class BreakAtLinesReloadTest < ConsoleTestCase
    def extra_file
      <<~RUBY
      def foo  # 1
        a = 10 # 2
        b = 20 # 3
        c = 30 # 4
      end
      RUBY
    end

    def program path
      <<~RUBY
      1| load #{path.dump}
      2| foo()
      3| load #{path.dump}
      4| foo()
      RUBY
    end

    def test_break_on_realoded_file_pending
      with_extra_tempfile do |extra_file|
        debug_code(program(extra_file.path)) do
          type "break #{extra_file.path}:2 do: p :xyzzy"
          type "break #{extra_file.path}:3"

          type 'c'
          assert_line_num 3
          assert_line_text(/xyzzy/)

          type 'c'
          assert_line_num 3         # should stop at reloaded file
          assert_line_text(/xyzzy/) # should do at line 2

          type 'c'
        end
      end
    end

    def test_break_on_reloaded_file
      code = <<~'DEBUG_CODE'
        1| require 'tempfile'
        2| tf = Tempfile.new('debug_gem_test')
        3| tf.puts(<<RUBY)
        4|  def foo
        5|   p 1
        6| end
        7| RUBY
        8| tf.close
        9| load tf.path
       10| # p :loeaded
       11| debugger do: "b #{tf.path}:2"
       12| foo
       13| tf.open
       14| tf.seek 0
       15| tf.puts(<<RUBY)
       16| def foo
       17|   p 0
       18|   p 1
       19| end
       20| RUBY
       21| tf.close
       22| load tf.path
       23| foo
      DEBUG_CODE

      debug_code code do
        type 'c'
        assert_line_num 2 # on tempfile
        type 'c'
        assert_line_num 2 # on tempfile
        type 'c'
      end
    end
  end

  class BreakAtLineTest < ConsoleTestCase
    def program path
      <<~RUBY
      1| load #{path.dump}
      RUBY
    end

    def extra_file
      <<~RUBY
      a = 1

      class C
        def m
          p :m
        end
      end
      RUBY
    end

    def test_break_on_line
      with_extra_tempfile do |extra_file|
        debug_code program(extra_file.path) do
          type "break #{extra_file.path}:1"
          type 'c'
          assert_line_num 1
          type 'c'
        end
      end
    end

    def program2
      <<~RUBY
      1| a = 1
      2| b = 2      # braek 2, stop at 2
      3|            # break 3, stop at def
      4| def foo    # break 4, stop at 5 (in foo)
      5|   a = 2
      6| end
      7|
      8| private def bar # break 8, stop at 9 (in bar)
      9|   a = 3
     10| end
     11|
     12| foo
     13| bar
      RUBY
    end

    def test_break_on_line_2
      debug_code program2 do
        type 'b 2'
        type 'c'
        assert_line_num 2
        type 'c'
      end
    end

    def test_break_on_line_3
      debug_code program2 do
        type 'b 3'
        type 'c'
        assert_line_num 4
        type 'c'
      end
    end

    def test_break_on_line_4
      debug_code program2 do
        type 'b 4'
        type 'c'
        assert_line_num 5
        type 'c'
      end
    end

    def test_break_on_line_8
      debug_code program2 do
        type 'b 8'
        type 'c'
        assert_line_num 9
        type 'c'
      end
    end
  end
end

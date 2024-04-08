# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class DebuggerMethodTest < ConsoleTestCase
    METHOD_PLACE_HOLDER = "__BREAK_METHOD__"
    SUPPORTED_DEBUG_METHODS = %w(debugger binding.break binding.b).freeze

    def debug_code(program)
      SUPPORTED_DEBUG_METHODS.each do |mid|
        super(program.gsub(METHOD_PLACE_HOLDER, mid))
      end
    end
  end

  class DebuggerMethodBasicTest < DebuggerMethodTest
    def program
      <<~RUBY
     1| class Foo
     2|   def bar
     3|     #{METHOD_PLACE_HOLDER}
     4|   end
     5| end
     6|
     7| Foo.new.bar
      RUBY
    end

    def test_breakpoint_fires_correctly
      debug_code(program) do
        type 'continue'
        assert_line_text('Foo#bar')
        type 'kill!'
      end
    end

    def test_debugger_method_in_subsession
      debug_code program do
        type 'c'
        assert_line_num 3
        type 'eval debugger do: "p 2 ** 32"'
        assert_line_text('4294967296')
        type 'eval debugger do: "p 2 ** 32;; n;; p 2 ** 33;;"'
        assert_line_num 4
        assert_line_text('4294967296')
        assert_line_text('8589934592')
        type 'c'
      end
    end
  end

  class DebuggerMethodWithPreCommandTest < DebuggerMethodTest
    def program
      <<~RUBY
     1| class Foo
     2|   def bar
     3|     #{METHOD_PLACE_HOLDER}(pre: "p 'aaaaa'")
     4|     baz
     5|   end
     6|
     7|   def baz
     8|     #{METHOD_PLACE_HOLDER}
     9|   end
    10| end
    11|
    12| Foo.new.bar
      RUBY
    end

    def test_breakpoint_executes_command_argument_correctly
      debug_code(program) do
        type 'continue'
        assert_line_text('Foo#bar')
        assert_line_text(/aaaaa/)
        # should stay at Foo#bar
        assert_no_line_text(/Foo#baz/)

        type 'continue'
        assert_line_text('Foo#baz')
        type 'continue'
      end
    end

    def test_debugger_doesnt_complain_about_duplicated_breakpoint
      debug_code(program) do
        type 'continue'
        assert_no_line_text(/duplicated breakpoint:/)
        type 'kill!'
      end
    end
  end

  class DebuggerMethodWithDoCommandTest < DebuggerMethodTest
    def program
      <<~RUBY
     1| class Foo
     2|   def bar
     3|     #{METHOD_PLACE_HOLDER}(do: "p 'aaaaa'")
     4|     baz
     5|   end
     6|
     7|   def baz
     8|     #{METHOD_PLACE_HOLDER}
     9|   end
    10| end
    11|
    12| Foo.new.bar
      RUBY
    end

    def test_breakpoint_execute_command_argument_correctly
      debug_code(program) do
        type 'continue'
        assert_line_text(/aaaaa/)
        # should move on to the next bp
        assert_line_text('Foo#baz')
        type 'continue'
      end
    end

    def test_debugger_doesnt_complain_about_duplicated_breakpoint
      debug_code(program) do
        type 'continue'
        assert_no_line_text(/duplicated breakpoint:/)
        type 'kill!'
      end
    end

    class ThreadManagementTest < DebuggerMethodTest
      def program
        <<~RUBY
         1| Thread.new do
         2|   #{METHOD_PLACE_HOLDER}(do: "p 'foo' + 'bar'")
         3| end.join
         4|
         5| Thread.new do
         6|   #{METHOD_PLACE_HOLDER}(do: "p 'bar' + 'baz'")
         7| end.join
         8|
         9| #{METHOD_PLACE_HOLDER}
        RUBY
      end

      def test_debugger_auto_continues_across_threads
        debug_code(program) do
          type 'continue'
          assert_line_text(/foobar/)
          assert_line_text(/barbaz/)
          type 'continue'
        end
      end
    end
  end

  class StepInTest <  ConsoleTestCase
    def program
      <<~RUBY
     1| def foo(num)
     2|   num
     3| end
     4|
     5| DEBUGGER__.step_in do
     6|   foo(10)
     7| end
      RUBY
    end

    def test_step_in_stops_the_program
      run_ruby(program, options: "-Ilib -rdebug") do
        assert_line_num(6)
        type "s"
        assert_line_num(2)
        type "num"
        assert_line_text(/10/)
        type "c"
      end
    end
  end

  class PreludeTest < ConsoleTestCase
    def program
      <<~RUBY
     1| require "debug/prelude"
     2| debugger_source = Kernel.method(:debugger).source_location
     3| a = 100
     4| b = 20
     5| debugger
     6|
     7| __END__
      RUBY
    end

    def test_prelude_defines_debugger_statements
      run_ruby(program, options: "-Ilib") do
        assert_line_num(5)
        type "a + b"
        assert_line_text(/120/)
        type "c"
      end
    end

    def test_require_config_doesnt_cancel_prelude
      run_ruby(program, options: "-Ilib -rdebug/config") do
        assert_line_num(5)
        type "a + b"
        assert_line_text(/120/)
        type "c"
      end
    end
  end
end

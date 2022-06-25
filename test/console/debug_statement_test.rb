# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class DebugStatementTest < ConsoleTestCase
    STATEMENT_PLACE_HOLDER = "__BREAK_STATEMENT__"
    SUPPORTED_DEBUG_STATEMENTS = %w(binding.break binding.b debugger).freeze

    def debug_code(program)
      SUPPORTED_DEBUG_STATEMENTS.each do |statement|
        super(program.gsub(STATEMENT_PLACE_HOLDER, statement))
      end
    end
  end

  class BasicTest < DebugStatementTest
    def program
      <<~RUBY
     1| class Foo
     2|   def bar
     3|     #{STATEMENT_PLACE_HOLDER}
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
        type 'q!'
      end
    end
  end

  class DebugStatementWithPreCommandTest < DebugStatementTest
    def program
      <<~RUBY
     1| class Foo
     2|   def bar
     3|     #{STATEMENT_PLACE_HOLDER}(pre: "p 'aaaaa'")
     4|     baz
     5|   end
     6|
     7|   def baz
     8|     #{STATEMENT_PLACE_HOLDER}
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
        type 'q!'
      end
    end
  end

  class DebugStatementWithDoCommandTest < DebugStatementTest
    def program
      <<~RUBY
     1| class Foo
     2|   def bar
     3|     #{STATEMENT_PLACE_HOLDER}(do: "p 'aaaaa'")
     4|     baz
     5|   end
     6|
     7|   def baz
     8|     #{STATEMENT_PLACE_HOLDER}
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
        type 'q!'
      end
    end

    class ThreadManagementTest < DebugStatementTest
      def program
        <<~RUBY
         1| Thread.new do
         2|   #{STATEMENT_PLACE_HOLDER}(do: "p 'foo' + 'bar'")
         3| end.join
         4|
         5| Thread.new do
         6|   #{STATEMENT_PLACE_HOLDER}(do: "p 'bar' + 'baz'")
         7| end.join
         8|
         9| #{STATEMENT_PLACE_HOLDER}
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
end

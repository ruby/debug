# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class DebugStatementTest < TestCase
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
        assert_debugger_out('Foo#bar')
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
        assert_debugger_out('Foo#bar')
        assert_debugger_out(/aaaaa/)
        # should stay at Foo#bar
        assert_debugger_noout(/Foo#baz/)

        type 'continue'
        assert_debugger_out('Foo#baz')
        type 'continue'
      end
    end

    def test_debugger_doesnt_complain_about_duplicated_breakpoint
      debug_code(program) do
        type 'continue'
        assert_debugger_noout(/duplicated breakpoint:/)
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
        assert_debugger_out(/aaaaa/)
        # should move on to the next bp
        assert_debugger_out('Foo#baz')
        type 'continue'
      end
    end

    def test_debugger_doesnt_complain_about_duplicated_breakpoint
      debug_code(program) do
        type 'continue'
        assert_debugger_noout(/duplicated breakpoint:/)
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
          assert_debugger_out(/foobar/)
          assert_debugger_out(/barbaz/)
          type 'continue'
        end
      end
    end
  end
end

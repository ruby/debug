# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class BindingBPTest < TestCase
    def program
      <<~RUBY
     1| class Foo
     2|   def bar
     3|     binding.break
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

  class BindingBPWithPreCommandTest < TestCase
    def program
      <<~RUBY
     1| class Foo
     2|   def bar
     3|     binding.break(pre: "p 'aaaaa'")
     4|     baz
     5|   end
     6|
     7|   def baz
     8|     binding.break
     9|   end
    10| end
    11|
    12| Foo.new.bar
      RUBY
    end

    def test_breakpoint_execute_command_argument_correctly
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

  class BindingBPWithDoCommandTest < TestCase
    def program
      <<~RUBY
     1| class Foo
     2|   def bar
     3|     binding.break(do: "p 'aaaaa'")
     4|     baz
     5|   end
     6|
     7|   def baz
     8|     binding.break
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

    class ThreadManagementTest < TestCase
      def program
        <<~RUBY
         1| Thread.new do
         2|   binding.b(do: "p 'foo' + 'bar'")
         3| end.join
         4|
         5| Thread.new do
         6|   binding.b(do: "p 'bar' + 'baz'")
         7| end.join
         8|
         9| binding.b
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
end

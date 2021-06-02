# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class BindingBPTest < TestCase
    def program
      <<~RUBY
     1| class Foo
     2|   def bar
     3|     binding.bp
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

  class BindingBPWithCommandTest < TestCase
    def program
      <<~RUBY
     1| class Foo
     2|   def bar
     3|     binding.bp(command: "continue")
     4|     baz
     5|   end
     6|
     7|   def baz
     8|     binding.bp
     9|   end
    10| end
    11|
    12| Foo.new.bar
      RUBY
    end

    def test_breakpoint_execute_command_argument_correctly
      debug_code(program) do
        type 'continue'
        assert_line_text('Foo#baz')
        type 'q!'
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class BindingBPTest < TestCase
    def program
      <<~RUBY
      class Foo
        def bar
          binding.bp
        end
      end

      Foo.new.bar
      RUBY
    end

    def test_breakpoint_fires_correctly
      debug_code(program) do
        type 'continue'
        assert_line_text(/Foo#bar/)
        type 'quit'
      end
    end
  end

  class BindingBPWithCommandTest < TestCase
    def program
      <<~RUBY
      class Foo
        def bar
          binding.bp(command: "continue")
          baz
        end

        def baz
          binding.bp
        end
      end

      Foo.new.bar
      RUBY
    end

    def test_breakpoint_execute_command_argument_correctly
      debug_code(program) do
        type 'continue'
        assert_line_text(/Foo#baz/)
        type 'quit'
      end
    end
  end
end

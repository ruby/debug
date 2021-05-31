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
end

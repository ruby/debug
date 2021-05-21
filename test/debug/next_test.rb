# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  #
  # Tests basic stepping behaviour.
  #
  class BasicNextTest < TestCase
    def program
      <<~RUBY
        a = 1
        b = 2
        c = 3
      RUBY
    end

    def test_next_goes_to_the_next_line
      debug_code(program) do
        type 'next'
        assert_line_num 2
        type 'quit'
        type 'y'
      end
    end

    def test_n_goes_to_the_next_line
      debug_code(program) do
        type 'n'
        assert_line_num 2
        type 'quit'
        type 'y'
      end
    end
  end

  #
  # Tests next behaviour in rescue clause.
  #
  class NextRescueTest < TestCase
    def program
      <<~RUBY
        module Foo
          class Bar
            def self.raise_error
              raise
            rescue
              p $!
            end
          end
          Bar.raise_error
        end
      RUBY
    end

    def test_next_steps_over_rescue_when_raising_from_method
      debug_code(program) do
        type 'break Foo::Bar.raise_error'
        type 'continue'
        type 'next'
        assert_line_num 6
        type 'quit'
        type 'y'
      end
    end
  end
end

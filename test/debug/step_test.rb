# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  #
  # Test basic stepping behaviour.
  #
  class BasicSteppingTest < TestCase
    def program
      <<~RUBY
        a = 1
        b = 2
        c = 3
      RUBY
    end

    def test_step_goes_to_the_next_statement
      debug_code(program) do
        type 'step'
        assert_line_num 2
        type 'quit'
        type 'y'
      end
    end

    def test_s_goes_to_the_next_statement
      debug_code(program) do
        type 's'
        assert_line_num 2
        type 'quit'
        type 'y'
      end
    end
  end

  #
  # Tests step/next with arguments higher than one.
  #
  class MoreThanOneStepTest < TestCase
    def program
      <<~RUBY
        2.times do |n|
          n
        end
        a += 1
      RUBY
    end

    def test_step_steps_out_of_blocks_when_done
      debug_code(program) do
        type 'step'
        assert_line_num 2
        type 'step'
        assert_line_num 3
        type 'step'
        assert_line_num 2
        type 'step'
        assert_line_num 3
        type 'step'
        assert_line_num 4
        type 'quit'
        type 'y'
      end
    end
  end
end

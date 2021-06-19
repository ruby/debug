# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class ConsoleStartTest < TestCase
    def program
      <<~RUBY
       1| a = 1
       2| b = 2
       3| require "debug"
       4| DEBUGGER__.console
       5| c = 3
       6| binding.bp
       7| "foo"
      RUBY
    end

    def test_session_starts_manually
      debug_code(program, boot_options: "", remote: false) do
        assert_line_num(5)
        type 'quit'
        type 'y'
      end
    end

    def test_later_breakpoint_fires_correctly
      debug_code(program, boot_options: "", remote: false) do
        assert_line_num(5)
        type 'c'
        assert_line_num(6)
        type 'quit'
        type 'y'
      end
    end
  end

  class RequireStartTest < TestCase
    def program
      <<~RUBY
       1| a = 1
       2| b = 2
       3| require "debug/run"
       4|
       5| c = 3
       6| binding.bp
       7| "foo"
      RUBY
    end

    def test_session_starts_manually
      debug_code(program, boot_options: "", remote: false) do
        assert_line_num(5)
        type 'quit'
        type 'y'
      end
    end

    def test_later_breakpoint_fires_correctly
      debug_code(program, boot_options: "", remote: false) do
        assert_line_num(5)
        type 'c'
        assert_line_num(6)
        type 'quit'
        type 'y'
      end
    end
  end
end

# frozen_string_literal: true

require_relative 'support/test_case'

module DEBUGGER__
  class AssertLineTextTest < TestCase
    def program
      <<~RUBY
        1| a = 1
      RUBY
    end

    def test_the_helper_takes_a_string_expectation_and_escape_it
      assert_raise_message(/Expected to include `foobar\\\?`/) do
        debug_code(program) do
          assert_line_text("foobar?")
        end
      end
    end

    def test_the_helper_takes_an_array_of_string_expectations_and_combine_them
      assert_raise_message(/Expected to include `foobar\\\?`/) do
        debug_code(program) do
          assert_line_text(["foo", "bar?"])
        end
      end
    end

    def test_the_helper_takes_a_regexp_expectation
      assert_raise_message(/Expected to include `\(\?-mix:foobar\)`/) do
        debug_code(program) do
          assert_line_text(/foobar/)
        end
      end
    end

    def test_the_helper_takes_an_array_of_regexp_expectations_and_combine_them
      assert_raise_message(/Expected to include `\(\?-mix:foobar\)`/) do
        debug_code(program) do
          assert_line_text([/foo/, /bar/])
        end
      end
    end

    def test_the_helper_raises_an_error_with_invalid_expectation
      assert_raise_message(/Unknown expectation value: 123/) do
        debug_code(program) do
          assert_line_text(123)
        end
      end
    end
  end
end


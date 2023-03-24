# frozen_string_literal: true

require_relative 'console_test_case'

module DEBUGGER__
  class AssertLineTextTest < ConsoleTestCase
    def program
      <<~RUBY
        a = 1
      RUBY
    end

    def test_the_helper_takes_a_string_expectation_and_escape_it
      assert_raise_message(/Expected to include `"foobar\\\\?/) do
        debug_code(program, remote: false) do
          assert_line_text("foobar?")
        end
      end
    end

    def test_the_helper_takes_an_array_of_string_expectations_and_combine_them
      assert_raise_message(/Expected to include `"foobar\\\\?/) do
        debug_code(program, remote: false) do
          assert_line_text(["foo", "bar?"])
        end
      end
    end

    def test_the_helper_takes_a_regexp_expectation
      assert_raise_message(/Expected to include `\/foobar\/`/) do
        debug_code(program, remote: false) do
          assert_line_text(/foobar/)
        end
      end
    end

    def test_the_helper_takes_an_array_of_regexp_expectations_and_combine_them
      assert_raise_message(/Expected to include `\/foo\.\*bar\/m`/) do
        debug_code(program, remote: false) do
          assert_line_text([/foo/, /bar/])
        end
      end
    end

    def test_the_helper_raises_an_error_with_invalid_expectation
      assert_raise_message(/Unknown expectation value: 123/) do
        debug_code(program, remote: false) do
          assert_line_text(123)
        end
      end
    end

    def test_the_test_fails_when_debuggee_on_unix_domain_socket_mode_doesnt_exist_after_scenarios
      omit "too slow now"

      assert_raise_message(/Expected to include `"foobar\\\\?/) do
        prepare_test_environment(program, steps) do
          debug_code_on_unix_domain_socket()
        end
      end
    end

    def test_the_test_fails_when_debuggee_on_tcpip_mode_doesnt_exist_after_scenarios
      omit "too slow now"

      assert_raise_message(/Expected to include `"foobar\\\\?/) do
        prepare_test_environment(program, steps) do
          debug_code_on_tcpip()
        end
      end
    end

    private

    def steps
      Proc.new{
        assert_line_text("foobar?")
      }
    end
  end
end


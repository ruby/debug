# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class BasicCatchTest < ConsoleTestCase
    def program
      <<~RUBY
      1| a = 1
      2| b = 2
      3|
      4| 1/0 rescue nil
      5| binding.b
      RUBY
    end

    def test_debugger_stops_when_the_exception_raised
      debug_code(program) do
        type 'catch ZeroDivisionError'
        assert_line_text(/#0  BP - Catch  "ZeroDivisionError"/)
        type 'continue'
        assert_line_text('Integer#/')
        type 'q!'
      end
    end

    def test_debugger_stops_when_child_exception_raised
      debug_code(program) do
        type 'catch StandardError'
        type 'continue'
        assert_line_text('Integer#/')
        type 'q!'
      end
    end

    def test_catch_command_isnt_repeatable
      debug_code(program) do
        type 'catch StandardError'
        type ''
        assert_no_line_text(/duplicated breakpoint/)
        type 'q!'
      end
    end

    def test_catch_works_with_command
      debug_code(program) do
        type 'catch ZeroDivisionError pre: p "1234"'
        assert_line_text(/#0  BP - Catch  "ZeroDivisionError"/)
        type 'continue'
        assert_line_text(/1234/)
        type 'continue'
        type 'continue'
      end

      debug_code(program) do
        type 'catch ZeroDivisionError do: p "1234"'
        assert_line_text(/#0  BP - Catch  "ZeroDivisionError"/)
        type 'continue'
        assert_line_text(/1234/)
        type 'continue'
      end
    end

    def test_catch_works_with_condition
      debug_code(program) do
        type 'catch ZeroDivisionError if: a == 2 do: p "1234"'
        assert_line_text(/#0  BP - Catch  "ZeroDivisionError"/)
        type 'continue'
        assert_no_line_text(/1234/)
        type 'continue'
      end
    end

    def test_debugger_rejects_duplicated_catch_bp
      debug_code(program) do
        type 'catch ZeroDivisionError'
        type 'catch ZeroDivisionError'
        assert_line_text(/duplicated breakpoint:/)
        type 'continue'

        assert_line_text('Integer#/') # stopped by catch
        type 'continue'

        type 'continue' # exit the final binding.b
      end
    end
  end

  class ReraisedExceptionCatchTest < ConsoleTestCase
    def program
      <<~RUBY
      1| def foo
      2|   bar
      3| rescue ZeroDivisionError
      4|   raise
      5| end
      6|
      7| def bar
      8|   1/0
      9| end
     10|
     11| foo
      RUBY
    end

    def test_debugger_stops_when_the_exception_raised
      debug_code(program) do
        type 'catch ZeroDivisionError'
        type 'continue'
        assert_line_text('Integer#/')
        type 's'
        assert_line_text('Object#bar')
        type 'q!'
      end
    end
  end

  class NamespacedExceptionCatchTest < ConsoleTestCase
    def program
      <<~RUBY
         1| class TestException < StandardError; end
         2|
         3| module Foo
         4|   class TestException < StandardError; end
         5|
         6|   def self.raised_exception
         7|     raise TestException
         8|   end
         9| end
        10|
        11| Foo.raised_exception rescue nil
      RUBY
    end

    def test_catch_without_namespace_does_not_stop_at_exception
      debug_code(program) do
        type 'catch TestException'
        type 'continue'
      end
    end

    def test_catch_with_namespace_stops_at_exception
      debug_code(program) do
        type 'catch Foo::TestException'
        type 'continue'
        assert_line_num(7)
        type 'continue'
      end
    end
  end

  class PathOptionTest < ConsoleTestCase
    def extra_file
      <<~RUBY
        def bar
          raise "bar"
        rescue
        end
      RUBY
    end

    def program(extra_file_path)
      <<~RUBY
     1| load "#{extra_file_path}"
     2|
     3| def foo
     4|   raise "foo"
     5| rescue
     6| end
     7|
     8| foo
     9| bar
      RUBY
    end

    def test_catch_only_stops_when_path_matches
      with_extra_tempfile do |extra_file|
        debug_code(program(extra_file.path)) do
          type "catch RuntimeError path: #{extra_file.path}"
          type 'c'
          assert_line_text(/bar/)
          type 'c'
        end
      end
    end

    def test_the_path_option_supersede_skip_path_config
      # skips the extra_file's breakpoint
      with_extra_tempfile do |extra_file|
        debug_code(program(extra_file.path)) do
          type "config set skip_path /#{extra_file.path}/"
          type "catch RuntimeError"
          type 'c'
          assert_line_text(/foo/)
          type 'c'
        end

        # ignores skip_path and stops at designated path
        debug_code(program(extra_file.path)) do
          type "config set skip_path /#{extra_file.path}/"
          type "catch RuntimeError path: #{extra_file.path}"
          type 'c'
          assert_line_text(/bar/)
          type 'c'
        end
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class StepTest < TestCase
    PROGRAM = <<~RUBY
      1| module Foo
      2|   class Bar
      3|     def self.a
      4|       "hello"
      5|     end
      6|   end
      7|   Bar.a
      8|   bar = Bar.new
      9| end
    RUBY

    def test_step_goes_to_the_next_statement
      run_protocol_scenario PROGRAM do
        req_step
        assert_line_num 2
        req_step
        assert_line_num 3
        req_step
        assert_line_num 7
        req_step
        assert_line_num 4
        req_step
        assert_line_num 5
        req_step
        assert_line_num 8
        req_terminate_debuggee
      end
    end
  end

  class StepTest2 < TestCase
    def program path
      <<~RUBY
        1| require_relative "#{path}"
        2| Foo.new.bar
      RUBY
    end

    def extra_file
      <<~RUBY
        class Foo
          def bar
            puts :hoge
          end
        end
      RUBY
    end

    def test_step_goes_to_the_next_file
      with_extra_tempfile do |extra_file|
        run_protocol_scenario(program(extra_file.path), cdp: false) do
          req_next
          assert_line_num 2
          req_step
          assert_line_num 3
          req_terminate_debuggee
        end
      end
    end
  end
end

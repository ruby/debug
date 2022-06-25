# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class LoadTest < ConsoleTestCase
    def program
      <<~RUBY
      1| r = require 'debug'
      2| binding.break
      RUBY
    end

    def test_require_debug_should_return_false
      debug_code(program) do
        type "c"
        type "p r"
        assert_line_text('false')
        type 'q!'
      end
    end
  end
end



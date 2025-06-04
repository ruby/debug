# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class RescueTest < ConsoleTestCase
    def program
      <<~RUBY
     1| 1.times do
     2|   begin
     3|     raise
     4|   rescue
     5|     p :ok
     6|   end
     7| end
      RUBY
    end

    def test_rescue
      debug_code program, remote: false do
        type 's'
        type 's'
        type 'c'
      end
    end
  end if RUBY_VERSION.to_f >= 3.5
end


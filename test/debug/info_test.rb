# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class InfoTest < TestCase
    class HandleInspectExceptionsTest < TestCase
      def program
        <<~RUBY
         1| class Baz
         2|   def inspect
         3|     raise 'Boom'
         4|   end
         5| end
         6|
         7| baz = Baz.new
         8| bar = 1
        RUBY
      end

      def test_info_wont_crash_debugger
        debug_code(program) do
          type 'b 8'
          type 'c'

          type 'info'
          assert_line_text('(rescued #<RuntimeError: Boom> during inspection)')
          type 'q!'
        end
      end
    end
  end
end

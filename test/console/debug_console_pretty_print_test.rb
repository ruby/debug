# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class DebugConsolePrettyPrintTest < ConsoleTestCase
    def program
      <<~RUBY
        1| class Foo
        2|   def pretty_print(pp) = pp.output.puts "pp Foo"
        3| end
        4| 
        5| foo = Foo.new
        6| 
        7| foo
      RUBY
    end

    def test_debug_console_passes_io_like_object_to_pretty_print
      debug_code(program) do
        type 'break 7'
        assert_line_text(/\#0  BP \- Line  .*/)
        type 'c'
        assert_line_num 7
        assert_line_text([
          /\[2, 7\] in .*/,
          /     2\|   def pretty_print\(pp\) = pp\.output\.puts "pp Foo"/,
          /     3\| end/,
          /     4\| /,
          /     5\| foo = Foo\.new/,
          /     6\| /,
          /=>   7\| foo/,
          /=>\#0\t<main> at .*/,
          //,
          /Stop by \#0  BP \- Line  .*/
        ])
        type 'foo'
        assert_line_text(/\#<NoMethodError: private method `puts' called for "":String> rescued during inspection/)
      end
    end
  end
end

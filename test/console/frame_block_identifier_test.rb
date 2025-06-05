# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__

  class FrameBlockIdentifierTest < ConsoleTestCase
    def program
      <<~RUBY
         1|
         2| class Whatever
         3|   def some_method
         4|     will_exit = false
         5|     loop do
         6|       return if will_exit
         7|       will_exit = true
         8|
         9|       begin
        10|         raise "foo"
        11|       rescue => e
        12|         puts "the end"
        13|       end
        14|     end
        15|   end
        16| end
        17|
        18| Whatever.new.some_method
      RUBY
    end

    def test_frame_block_identifier
      debug_code(program) do
        type 'b 12'
        type 'c'
        assert_line_num 12
        assert_line_text([
          /\[7, 16\] in .*/,
          /     7\|       will_exit = true/,
          /     8\| /,
          /     9\|       begin/,
          /    10\|         raise "foo"/,
          /    11\|       rescue => e/,
          /=>  12\|         puts "the end"/,
          /    13\|       end/,
          /    14\|     end/,
          /    15\|   end/,
          /    16\| end/,
          /=>\#0\tWhatever\#some_method at .*/,
          /  \#1\t.*/,
          /  \# and (?:2|3) frames \(use `bt' command for all frames\)/,
          //,
          /Stop by \#0  BP \- Line  .*/
        ])
        type 'c'
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class ThreadTest < TestCase
    def program
      <<~RUBY
     1| Thread.new do
     2|   i = 0
     3|   while true do
     4|     i += 1
     5|   end
     6| end
     7| sleep 0.1
     8| binding.b
      RUBY
    end

    def test_prints_all_threads
      debug_code(program) do
        type 'c'
        type 'thread'
        assert_line_text(
          [
            /--> #0 \(sleep\)@.*:8:in `<main>'/,
            /#1 \(sleep\)/
          ]
        )
        type 'q!'
      end
    end

    def test_switches_to_the_other_thread
      debug_code(program) do
        type 'c'
        type 'thread 1'
        assert_line_text(
          [
            /#0 \(sleep\)@.*:8:in `<main>'/,
            /--> #1 \(sleep\)/
          ]
        )
        type 'q!'
      end
    end
  end
end

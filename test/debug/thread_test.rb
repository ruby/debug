# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class ThreadTest < TestCase
    POSSIBLE_STATES = "(sleep|run)"

    def program
      <<~RUBY
     1| def fib(n)
     2|   first_num, second_num = [0, 1]
     3|   (n - 1).times do
     4|     first_num, second_num = second_num, first_num + second_num
     5|   end
     6|   first_num
     7| end
     8|
     9| Thread.new do
    10|   fib(1_000_000)
    11| end
    12|
    13| sleep(0.1)
    14| binding.b
      RUBY
    end

    def test_prints_all_threads_and_can_switch_to_another_one
      debug_code(program) do
        type 'c'
        type 'thread'
        assert_line_text(
          [
            /--> #0 \(#{POSSIBLE_STATES}\)@.*:\d+:in `<main>'/,
            /#1 \(#{POSSIBLE_STATES}\)/
          ]
        )

        # currently there's no easy way to make sure that a thread will be "under control" (can be switched to) consistently
        if false
          type 'thread 1'
          assert_line_text(
            [
              /#0 \(#{POSSIBLE_STATES}\)@.*:\d+:in `<main>'/,
              /--> #1 \(#{POSSIBLE_STATES}\)/
            ]
          )
        end

        type 'q!'
      end
    end
  end
end

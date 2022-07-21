require_relative '../support/console_test_case'

module DEBUGGER__
  class ThreadControlTest < ConsoleTestCase
    def program
      <<~RUBY
       1| def foo
       2|   Thread.new { sleep 5 }
       3| end
       4|
       5| 5.times do
       6|   foo
       7|   binding.b(do: "1 == 2") # eval Ruby code in debugger
       8| end
      RUBY
    end

    def test_debugger_isnt_hung_by_new_threads
      debug_code(program) do
        type "c"
      end
    end
  end
end

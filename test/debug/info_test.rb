# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
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
        assert_line_text('#<RuntimeError: Boom>')
        type 'q!'
      end
    end
  end

  class BasicInfoTest < TestCase
    def program
      <<~RUBY
     1| def foo
     2|   @var = 10
     3|   a = 1
     4|   @var + 1
     5| end
     6|
     7| foo
      RUBY
    end

    def test_info_prints_locals_by_default
      debug_code(program) do
        type 'b 5'
        type 'c'
        type 'info'
        assert_line_text(
          "%self => main\r\n" \
          "%return => 11\r\n" \
          "a => 1\r\n" \
          "@var => 10\r\n"
        )
        type 'q!'
      end
    end
  end

  class InfoThreadsTest < TestCase
    def program
      <<~RUBY
       1| def foo
       2|   Thread.new { sleep 30 }
       3| end
       4|
       5| foo
       6| sleep 0.1 # make sure the thread stops
       7| "placeholder"
      RUBY
    end

    def test_prints_current_thread
      debug_code(program) do
        type 'b 7'
        type 'c'
        type 'info threads'
        assert_line_text(/#0 \(sleep\)@.*:7:in `<main>'/)
        type 'q!'
      end
    end

    def test_prints_the_other_thread
      debug_code(program) do
        type 'b 7'
        type 'c'
        type 'info threads'
        assert_line_text(/#1 \(sleep\)@.*:2 sleep/)
        type 'q!'
      end
    end
  end
end

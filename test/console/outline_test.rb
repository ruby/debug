# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class OutlineTest < ConsoleTestCase
    def program
      <<~RUBY
     1| class Foo
     2|   def initialize
     3|     @var = "foobar"
     4|   end
     5|
     6|   def bar; end
     7|   def self.baz; end
     8| end
     9|
    10| foo = Foo.new
    11|
    12| binding.b
      RUBY
    end

    def test_outline_lists_local_variables
      debug_code(program) do
        type 'c'
        type 'outline'
        assert_line_text(/locals: foo/)
        type 'c'
      end
    end

    def test_outline_lists_object_info
      debug_code(program) do
        type 'c'
        type 'outline foo'
        assert_line_text([
          /Foo#methods: bar/,
          /instance variables: @var/
        ])
        type 'c'
      end
    end

    def test_outline_lists_class_info
      debug_code(program) do
        type 'c'
        type 'outline Foo'
        assert_line_text(
          [
            /Class#methods:\s+allocate/,
            /Foo\.methods: baz/,
          ]
        )
        type 'c'
      end
    end

    def test_outline_aliases
      debug_code(program) do
        type 'c'
        type 'outline'
        assert_line_text(/locals: foo/)
        type 'ls'
        assert_line_text(/locals: foo/)
        type 'c'
      end
    end
  end

  class OutlineThreadLockingTest < ConsoleTestCase
    def program
      <<~RUBY
     1| th0 = Thread.new{sleep}
     2| $m = Mutex.new
     3| th1 = Thread.new do
     4|   $m.lock
     5|   sleep 1
     6|   $m.unlock
     7| end
     8|
     9| def self.constants # overriding constants is only one of the ways to cause deadlock with outline
    10|   $m.lock
    11|   []
    12| end
    13|
    14| sleep 0.5
    15| debugger
      RUBY
    end

    def test_outline_doesnt_cause_deadlock
      debug_code(program) do
        type 'c'
        type 'ls'
        assert_line_text(/locals: th0/)
        type 'c'
      end
    end
  end
end

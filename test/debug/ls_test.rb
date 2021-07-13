# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class LsTest < TestCase
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

    def test_ls_lists_local_variables
      debug_code(program) do
        type 'c'
        type 'ls'
        assert_line_text(/locals.*: _  foo/)
        type 'c'
      end
    end

    def test_ls_lists_object_info
      debug_code(program) do
        type 'c'
        type 'ls foo'
        assert_line_text([
          /Foo#methods.*: bar/,
          /instance variables.*: @var/
        ])
        type 'c'
      end
    end

    def test_ls_lists_class_info
      debug_code(program) do
        type 'c'
        type 'ls Foo'
        assert_line_text(
          [
            /Class#methods.*: allocate/,
            /Foo\.methods.*: baz/,
          ]
        )
        type 'c'
      end
    end
  end
end

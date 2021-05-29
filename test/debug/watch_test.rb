# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class LocalVariableWatchingTest < TestCase
    def program
      <<~RUBY
        a = 1
        b = 2
        c = 3
        a = 2
        foo = "foo" # stops here
      RUBY
    end

    def test_debugger_stops_when_the_expression_changes
      debug_code(program) do
        type 'step'
        type 'watch a'
        type 'continue'
        assert_line_num(5) # stops at the next line
        type 'quit'
        type 'y'
      end
    end
  end

  class InstanceVariableWatchingTest < TestCase
    def program
      <<~RUBY
        @a = 1
        @b = 2
        @c = 3
        @a = 2
        foo = "foo" # stops here
      RUBY
    end

    def test_debugger_stops_when_the_expression_changes
      debug_code(program) do
        type 'step'
        type 'watch @a'
        type 'continue'
        assert_line_num(5) # stops at the next line
        type 'quit'
        type 'y'
      end
    end
  end

  class MethodWatchingTest < TestCase
    def program
      <<~RUBY
        class Student
          attr_accessor :name

          def initialize(name)
            @name = name
          end
        end

        s1 = Student.new("John")
        s2 = Student.new("Jane")

        s2.name = "Jenny"
        s1.name = "Josh"

        s2.name = "Penny" # stops here
      RUBY
    end

    def test_debugger_stops_when_the_expression_changes
      debug_code(program) do
        type 'b 10'
        type 'continue'
        type 'watch s1.name'
        type 'continue'
        assert_line_num(15) # stops at the next line
        type 'quit'
        type 'y'
      end
    end
  end
end

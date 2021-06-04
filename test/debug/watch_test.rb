# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class TopLevelInstanceVariableWatchingTest < TestCase
    def program
      <<~RUBY
        1| @a = 1
        2| @b = 2
        3| @c = 3
        4| @a = 2
        5| foo = "foo" # stops here
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

  class ObjectInstanceVariableWatchingTest < TestCase
    def program
      <<~RUBY
        class Student
          attr_accessor :name

          def initialize(name)
            @name = name
            binding.bp(command: "watch @name")
          end
        end

        class Teacher
          attr_accessor :name

          def initialize(name)
            @name = name
          end
        end

        s1 = Student.new("John")
        t1 = Teacher.new("Jane") # it shouldn't stop for this
        s1.name = "Josh"
        "foo"
      RUBY
    end

    def test_debugger_only_stops_when_the_ivar_of_instance_changes
      debug_code(program) do
        type 'continue'
        assert_line_text('Student#initialize(name="John")')
        type 'continue'
        assert_line_num(21) # stops when assigned to "Josh"
        type 'quit'
        type 'y'
      end
    end
  end
end

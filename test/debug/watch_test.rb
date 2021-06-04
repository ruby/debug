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
         1| class Student
         2|   attr_accessor :name
         3|
         4|   def initialize(name)
         5|     @name = name
         6|     binding.bp(command: "watch @name")
         7|   end
         8| end
         9|
        10| class Teacher
        11|   attr_accessor :name
        12|
        13|   def initialize(name)
        14|     @name = name
        15|   end
        16| end
        17|
        18| s1 = Student.new("John")
        19| t1 = Teacher.new("Jane") # it shouldn't stop for this
        20| s1.name = "Josh"
        21| "foo"
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

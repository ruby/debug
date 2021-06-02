# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class LocalVariableWatchingTest < TestCase
    def program
      <<~RUBY
        1| a = 1
        2| b = 2
        3| c = 3
        4| a = 2
        5| foo = "foo" # stops here
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
  end if false # To be removed

  class InstanceIVarWatchingTest < TestCase
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

  class MethodWatchingTest < TestCase
    def program
      <<~RUBY
       1| class Student
       2|   attr_accessor :name
       3|
       4|   def initialize(name)
       5|     @name = name
       6|   end
       7| end
       8|
       9| s1 = Student.new("John")
      10| s2 = Student.new("Jane")
      11|
      12| s2.name = "Jenny"
      13| s1.name = "Josh"
      14|
      15| s2.name = "Penny" # stops here
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

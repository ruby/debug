# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class ObjectInstanceVariableWatchingTest < TestCase
    def program
      <<~RUBY
         1| class Student
         2|   attr_accessor :name
         3|
         4|   def initialize(name)
         5|     @name = name
         6|     binding.b
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
        type 'watch @name'
        assert_line_text(/#0  BP - Watch  #<Student:.*> @name = John/)
        type 'continue'
        assert_line_text(/Stop by #0  BP - Watch  #<Student:.*> @name = John -> Josh/)
        type 'continue'
      end
    end

    def test_watch_command_isnt_repeatable
      debug_code(program) do
        type 'continue'
        type 'watch @name'
        type ''
        assert_no_line_text(/duplicated breakpoint/)
        type 'quit!'
      end
    end

    def test_watch_works_with_command
      debug_code(program) do
        type 'continue'
        type 'watch @name pre: p "1234"'
        assert_line_text(/#0  BP - Watch  #<Student:.*> @name = John/)
        type 'continue'
        assert_line_text(/1234/)
        type 'continue'
      end

      debug_code(program) do
        type 'continue'
        type 'watch @name do: p "1234"'
        assert_line_text(/#0  BP - Watch  #<Student:.*> @name = John/)
        type 'b 21'
        type 'continue'
        assert_line_text(/1234/)
        type 'continue'
      end
    end

    class ConditionTest < TestCase
      def program
        <<~RUBY
         1| class Student
         2|   attr_accessor :name, :age
         3|
         4|   def initialize(name, age)
         5|     @name = name
         6|     @age = age
         7|     binding.b(do: "watch @age if: name == 'Sean'")
         8|   end
         9| end
        10|
        11| stan = Student.new("Stan", 30)
        12| stan.age += 1
        13| # only stops for Sean's age change
        14| sean = Student.new("Sean", 25)
        15| sean.age += 1
        16|
        17| a = 1 # additional line for line tp
        RUBY
      end

      def test_condition_is_evaluated_in_the_watched_object
        debug_code(program) do
          type 'continue'
          assert_line_text(/Stop by #\d  BP - Watch  #<Student:.*> @age = 25 -> 26/)
          type 'continue'
        end
      end
    end

    class PathOptionTest < TestCase
      def extra_file
        <<~RUBY
        STUDENT.age = 25
        _ = 1 # for the debugger to stop
        RUBY
      end

      def program(extra_file_path)
        <<~RUBY
         1| class Student
         2|   attr_accessor :age
         3|
         4|   def initialize
         5|     binding.b(do: "watch @age path: #{extra_file_path}")
         6|   end
         7| end
         8|
         9| STUDENT = Student.new
        10|
        11| load "#{extra_file_path}"
        12|
        13| STUDENT.age = 30
        14| _ = 1
        RUBY
      end

      def test_watch_only_stops_when_path_matches
        with_extra_tempfile do |extra_file|
          debug_code(program(extra_file.path)) do
            type 'c'
            assert_line_text(/@age =  -> 25/)
            type 'c'
          end
        end
      end
    end
  end
end

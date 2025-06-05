# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class HandleInspectExceptionsTest < ConsoleTestCase
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
        type 'kill!'
      end
    end
  end

  class BasicInfoTest < ConsoleTestCase
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
          "%self = main\r\n" \
          "_return = 11\r\n" \
          "a = 1\r\n" \
          "@var = 10\r\n"
        )
        type 'kill!'
      end
    end

    def test_info_conflict_lvar
      code = <<~RUBY
      1| def foo _return
      2|   :ok
      3| end
      4| foo :ret
      RUBY

      debug_code code do
        type 'b 3'
        type 'c'
        assert_line_num 3
        type 'i'
        assert_line_text [/%return = :ok/, /_return = :ret/]
        type 'c'
      end
    end

    def test_info_print_modified_locals
      debug_code program do
        type 'b 4'
        type 'c'
        type 'info'
        assert_line_text(/a = 1\b/)
        type 'a = 128'
        type 'info'
        assert_line_text(/a = 128\b/)
        type 'c'
      end
    end
  end

  class InfoThreadsTest < ConsoleTestCase
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
        assert_line_text(/#0 \(sleep\)@.*:7:in [`']<main>'/)
        type 'kill!'
      end
    end

    def test_prints_the_other_thread
      debug_code(program) do
        type 'b 7'
        type 'c'
        type 'info threads'
        assert_line_text(/#1 \(sleep\)@.*:2 sleep/)
        type 'kill!'
      end
    end
  end

  class InfoConstantTest < ConsoleTestCase
    def program
      <<~RUBY
         1|
         2| class C0
         3|   C0_CONST1 = -1
         4|   C0_CONST2 = -2
         5| end
         6|
         7| class D
         8|   D_CONST1 = 1
         9|   D_CONST2 = 1
        10|   class C1 < C0
        11|     CONST1 = 1
        12|     CONST2 = 2
        13|     l1 = 10
        14|     l2 = 20
        15|     @i1 = 100
        16|     @i2 = 200
        17|
        18|     def foo
        19|       :foo
        20|     end
        21|   end
        22| end
        23|
        24| class E
        25|   E_CONST1 = C0
        26|   def self.foo
        27|     D
        28|   end
        29| end
        30|
        31| D::C1.new.foo
      RUBY
    end

    def test_info_constant
      debug_code(program) do
        type 'info'
        assert_line_text(/%self = main/)
        assert_no_line_text(/SystemExit = SystemExit/)
        type 'info constant'
        assert_line_text([
          /SystemExit = SystemExit/,
        ])
        type 'b 17'
        type 'b 19'
        type 'c'
        assert_line_num 18

        type 'info'
        assert_line_text([
          /%self = D::C1/,
          /l1 = 10/,
          /l2 = 20/,
          /@i1 = 100/,
          /@i2 = 200/,
          /CONST1 = 1/,
          /CONST2 = 2/
        ])
        assert_no_line_text(/C1 = D::C1/)

        type 'info constants'
        assert_line_text([
          /C1 = D::C1/
        ])

        type 'c'
        assert_line_num 19

        type 'info'
        assert_line_text(/%self = \#<D::C1/)
        type 'info constants'
        assert_line_text([
          /CONST1 = 1/,
          /CONST2 = 2/,
          /C0_CONST1 = \-1/,
          /C0_CONST2 = \-2/,
          /C1 = D::C1/,
          /D_CONST1 = 1/,
          /D_CONST2 = 1/,
        ])

        type 'c'
      end
    end

    def test_info_constant_twice
      debug_code program do
        type 'i c' # on Ruby 3.2, `Set` loads `set.rb`
        type 'i c' # on Ruby 3.2, accessing `SortedSet` raises an error
        # #<RuntimeError: The `SortedSet` class has been extracted from the `set` library.
        #                 You must use the `sorted_set` gem or other alternatives.
        type 'c'
      end
    end

    def test_info_constant_with_expression
      debug_code(program) do
        type "b 31"
        type "c"
        assert_line_num 31

        type "info constants E"
        assert_line_text([
          /E_CONST1 = C0/,
        ])

        type "info constants E.foo"
        assert_line_text([
          /C1 = D::C1/,
          /D_CONST1 = 1/,
          /D_CONST2 = 1/,
        ])

        type "info constants E::E_CONST1"
        assert_line_text([
          /C0_CONST1 = -1/,
          /C0_CONST2 = -2/,
        ])

        type "c"
      end
    end

    def test_info_constant_with_expression_errors
      debug_code(program) do
        type "b 31"
        type "c"
        assert_line_num 31

        type "info constants foo"
        assert_line_text([
          /eval error: undefined local variable or method [`']foo' for main/,
        ])

        type "c"
      end
    end

    def test_info_constant_with_non_module_expression
      debug_code(program) do
        type "b 31"
        type "c"
        assert_line_num 31

        type "info constants 3"
        assert_line_text([
          /3 \(by 3\) is not a Module./
        ])

        type "c"
      end
    end
  end

  class InfoIvarsTest < ConsoleTestCase
    def program
      <<~RUBY
      1| class C
      2|   def initialize
      3|     @a = :a
      4|     @b = :b
      5|   end
      6| end
      7| c = C.new
      8| c
      RUBY
    end

    def test_ivar
      debug_code program do
        type 'b 5'
        type 'c'
        assert_line_num 5
        type 'info ivars'
        assert_line_text(/@a/)
        assert_line_text(/@b/)
        type 'info ivars /b/'
        assert_no_line_text(/@a/)
        assert_line_text(/@b/)
        type 'c'
      end
    end

    def test_ivar_obj
      debug_code program do
        type 'u 8'
        assert_line_num 8
        type 'info ivars'
        assert_no_line_text(/@/)
        type 'info ivars c'
        assert_line_text(/@a/)
        assert_line_text(/@b/)
        type 'info ivars c /b/'
        assert_no_line_text(/@a/)
        assert_line_text(/@b/)
        type 'c'
      end
    end

    def test_ivar_abbrev
      debug_code program do
        type 'b 5'
        type 'c'
        assert_line_num 5

        %w[ i iv iva ivar ivars
            in ins inst insta instan instanc instance
            instance_ instance_v instance_va instance_variable instance_variables].each{|c|
          type "info #{c}"
          assert_line_text(/@a/)
          assert_line_text(/@b/)
        }
        type 'c'
      end
    end
  end

  class InfoBreaksTest < ConsoleTestCase
    def program
      <<~RUBY
      1| @a = 1
      2| @b = 2
      3| @c = 3
      RUBY
    end

    def test_ivar_abbrev
      debug_code program do
        type 'next'
        assert_line_num 2
        type 'break 3'
        type 'watch @a'
        type 'i b'
        assert_line_text(/:3/)
        assert_line_text(/@a/)
        type 'c'
        assert_line_num 3
        type 'c'
      end
    end
  end

  class InfoThreadLockingTest < ConsoleTestCase
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
     9| o = Object.new
    10| def o.inspect
    11|   $m.lock
    12|   "foo"
    13| end
    14|
    15| sleep 0.5
    16| debugger
      RUBY
    end

    def test_info_doesnt_cause_deadlock
      debug_code(program) do
        type 'c'
        type 'info'
        assert_line_text(/%self = main/)
        type 'c'
      end
    end
  end
end

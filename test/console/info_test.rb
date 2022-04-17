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
          "%self = main\r\n" \
          "_return = 11\r\n" \
          "a = 1\r\n" \
          "@var = 10\r\n"
        )
        type 'q!'
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

  class InfoConstantTest < TestCase
    def program
      <<~RUBY
         1|
         1| class C0
         2|   C0_CONST1 = -1
         3|   C0_CONST2 = -2
         4| end
         5|
         6| class D
         7|   D_CONST1 = 1
         8|   D_CONST2 = 1
         9|   class C1 < C0
        10|     CONST1 = 1
        11|     CONST2 = 2
        12|     l1 = 10
        13|     l2 = 20
        14|     @i1 = 100
        15|     @i2 = 200
        16|
        17|     def foo
        18|       :foo
        19|     end
        20|   end
        21| end
        22|
        23| D::C1.new.foo
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
  end
end

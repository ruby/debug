# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class RecordOnOffTest < ConsoleTestCase
    def program
      <<~RUBY
        1|
        2| p a  = 1
        3| p a += 1
        4| binding.b do: 'record on'
        5| p a += 1
        6| p a += 1
        7| binding.b
        8| p a += 1
        9| p a += 1
      RUBY
    end

    def test_step_back_at_first
      debug_code(program) do
        type 'step back'
        assert_line_text(/Can not step back more\./)
        type 'q!'
      end
    end

    def test_record_on_off
      debug_code(program) do
        type 'c'
        assert_line_num 7
        type 'step back'
        type 'step back'
        type 'step back'
        assert_line_text([
          /\[replay\] =>   5\| p a \+= 1/,
        ])
        type 'step back'
        assert_line_text(/\[replay\] Can not step back more\./)
        type 'step'
        assert_line_num 6
        assert_line_text([
          /\[replay\] =>   6\| p a \+= 1/,
        ])
        type 'step'
        assert_line_num 7
        assert_line_text([
          /\[replay\] =>   7\| binding\.b/,
        ])
        type 'record off'
        type 'step'
        type 'step'
        assert_line_num 8
        type 'step'
        assert_line_num 9
        type 'step back'
        assert_line_text(/Can not step back more\./)
        type 'q!'
      end
    end
  end

  class RecordTest < ConsoleTestCase
    def program
      <<~RUBY
         1|
         2| def foo n
         3|   n += 10
         4|   bar n + 1
         5| end
         6|
         7| def bar n
         8|   n += 100
         9|   p n
        10| end
        11|
        12| foo 10
        13|
      RUBY
    end

    def test_1629263892
      debug_code(program) do
        type 'b 9'
        type 'record on'
        type 'c'
        assert_line_num 9
        assert_line_text([
          /=>\#0\tObject\#bar\(n=121\)/,
          /  \#1\tObject\#foo\(n=20\)/,
        ])
        type 'step back'
        type 'step back'
        assert_line_text([
          /\[replay\] =>\#0\tObject\#bar\(n=21\)/,
          /\[replay\]   \#1\tObject\#foo\(n=20\)/,
        ])
        type 'i'
        assert_line_text([
          /\[replay\] n = 21/
        ])
        type 'step back'
        assert_line_text([
          /\[replay\] =>\#0\tObject\#foo\(n=20\)/,
        ])
        type 'i'
        assert_line_text([
          /\[replay\] n = 20/
        ])
        type 'step back'
        type 'i'
        assert_line_text([
          /\[replay\] n = 10/
        ])
        type 'step'
        assert_line_num 4
        type 'i'
        assert_line_text([
          /\[replay\] n = 20/
        ])
        type 'step '
        type 'i'
        assert_line_text([
          /\[replay\] n = 21/
        ])
        type 'step'
        assert_line_num 9
        type 'i'
        assert_line_text([
          /\[replay\] n = 121/
        ])
        type 'step'
        assert_line_num 9
        type 'step'
        assert_line_num 10
        type 'c'
      end
    end
  end

  class RecordOnAfterStoppingOnceTest < ConsoleTestCase
    def program
      <<~RUBY
        1| a=1
        2|
        3| b=1
        4|
        5| c=1
        6| p a
      RUBY
    end

    def test_1656237686
      debug_code(program) do
        type 'record on'
        type 'record off'
        type 'record on'
        type 'b 5'
        type 'c'
        assert_line_num 5
        type 'step back'
        assert_line_text([
          /\[replay\] =>\#0\t<main> at .*/
        ])
        type 'q!'
      end
    end
  end
end

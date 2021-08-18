# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class RecordOnOffTest < TestCase
    def program
      <<~RUBY
        1|
        1| p a  = 1
        2| p a += 1
        3| binding.b do: 'record on'
        4| p a += 1
        5| p a += 1
        6| binding.b
        7| p a += 1
        8| p a += 1
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

  class RecordTest < TestCase
    def program
      <<~RUBY
         1|
         1| def foo n
         2|   n += 10
         3|   bar n + 1
         4| end
         5|
         6| def bar n
         7|   n += 100
         8|   p n
         9| end
        10|
        11| foo 10
        12|
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
end

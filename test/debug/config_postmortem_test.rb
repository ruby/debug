# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class PostmortemTest < TestCase
    def program
      <<~RUBY
        1| def foo y = __LINE__
        2|   bar
        3| end
        4| def bar x = __LINE__
        5|   raise
        6| end
        7| foo
      RUBY
    end

    def test_config_postmortem
      debug_code(program) do
        type 'config postmortem = true'
        type 'c'
        assert_line_text(/Enter postmortem mode with RuntimeError/)
        type 'p x'
        assert_line_text(/=> 4/)
        type 'up'
        type 'p y'
        assert_line_text(/=> 1/)
        type 'step'
        assert_line_text(/Can not use this command on postmortem mode/)
        type 'c'
        assert_finish
      end
    end

    def test_env_var_postmortem
      ENV["RUBY_DEBUG_POSTMORTEM"] = "true"
      debug_code(program) do
        type 'c'
        assert_line_text(/Enter postmortem mode with RuntimeError/)
        type 'p x'
        assert_line_text(/=> 4/)
        type 'up'
        type 'p y'
        assert_line_text(/=> 1/)
        type 'step'
        assert_line_text(/Can not use this command on postmortem mode/)
        type 'c'
        assert_finish
      end
    ensure
      ENV["RUBY_DEBUG_POSTMORTEM"] = nil
    end
  end

  class CustomPostmortemTest < TestCase
    def program
      <<~RUBY
        1| DEBUGGER__::CONFIG[:postmortem] = true
        2| def foo y = __LINE__
        3|   bar
        4| end
        5| def bar x = __LINE__
        6|   raise
        7| end
        8| begin
        9|   foo
       10| rescue => e
       11|   DEBUGGER__::SESSION.enter_postmortem_session e
       12| end
       13| binding.b
       14| v = :ok1
       15| DEBUGGER__::CONFIG[:postmortem] = false
      RUBY
    end

    def test_config_postmortem
      debug_code(program) do
        type 'c'
        assert_line_num 6
        type 'bt'
        assert_line_text([/bar/, /foo/])
        type 'c'
        assert_line_num 13
        type 'p v'
        assert_line_text(/=> nil/)
        type 'step'
        type 'step'
        type 'p v'
        assert_line_text(/=> :ok1/)
        type 'c'
        assert_finish
      end
    end
  end
end

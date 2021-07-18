# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class SetTest < TestCase
    def program
      <<~RUBY
        1| def foo
        1|   bar
        2| end
        3| def bar
        4|   p :bar
        5| end
        6| foo
      RUBY
    end

    def test_config_show
      debug_code(program) do
        type 'config'
        # show all configurations with descriptions
        assert_line_text([
          /show_src_lines = \(default\)/,
          /show_frames = \(default\)/
        ])
        # only show this configuratio
        type 'config show_frames'
        assert_line_text([
          /show_frames = \(default\)/
        ])
        type 'q!'
      end
    end

    def test_config_show_frames_set_with_eq
      debug_code(program) do
        type 'config show_frames=1'
        assert_line_text([
          /show_frames = 1/
        ])
        type 'b 5'
        type 'c'
        assert_line_num 5
        # only show 1 frame, and 2 frames are left.
        assert_line_text([
          /  # and 2 frames \(use `bt' command for all frames\)/,
        ])
        type 'q!'
      end
    end

    def test_config_show_frames_set
      debug_code(program) do
        type 'config set show_frames 1'
        assert_line_text([
          /show_frames = 1/
        ])
        type 'b 5'
        type 'c'
        assert_line_num 5
        # only show 1 frame, and 2 frames are left.
        assert_line_text([
          /  # and 2 frames \(use `bt' command for all frames\)/,
        ])
        type 'q!'
      end
    end
  end

  class ShowSrcLinesTest < TestCase
    def program
      <<~RUBY
      1| p 1
      2| p 2
      3| p 3
      4| p 4
      5| p 5
      6| p 6
      7| p 7
      8| p 8
      9| p 9
      10| binding.b
      11| p 11
      12| p 12
      13| p 13
      14| p 14
      15| p 15
      RUBY
    end

    def test_show_src_lines_control_the_lines_displayed_on_breakpoint
      debug_code(program) do
        type 'config set show_src_lines 2'
        type 'continue'
        assert_line_text([
          /9| p 9/,
          /=>   10| binding.b/
        ])

        assert_no_line_text(/p 11/)
        type 'continue'
      end
    end
  end

  class ShowFramesTest < TestCase
    def program
      <<~RUBY
     1| def m1
     2|   m2
     3| end
     4|
     5| def m2
     6|   m3
     7| end
     8|
     9| def m3
    10|   foo
    11| end
    12|
    13| def foo
    14|   binding.b
    15| end
    16|
    17| m1
      RUBY
    end

    def test_show_frames_control_the_frames_displayed_on_breakpoint
      debug_code(program) do
        type 'config set show_frames 2'
        type 'continue'
        assert_line_text([
          /Object#foo at/,
          /Object#m3 at/
        ])

        assert_no_line_text(/Object#m2/)
        type 'continue'
      end
    end
  end

  class SkipPathTest < TestCase
    def lib_file
      <<~RUBY
        def lib_m1
          yield
        end
        def lib_m2
          2
        end
      RUBY
    end

    def program(lib_file)
      <<~RUBY
     1| DEBUGGER__::CONFIG[:skip_path] = [/library/]
     2|
     3| load "#{lib_file.path}"
     4|
     5| def foo
     6|   1
     7| end
     8|
     9| result = lib_m1 do
    10|   foo + lib_m2
    11| end
    12|
    13| binding.b
      RUBY
    end

    def write_lib_temp_file
      Tempfile.create(%w[library .rb]).tap do |f|
        f.write(lib_file)
        f.close
      end
    end

    def test_skip_path_skip_frames_that_match_the_path
      lib_file = write_lib_temp_file
      debug_code(program(lib_file)) do
        type 'b 9'
        type 'continue'
        type 's'

        # skip definition of lib_m1
        assert_line_text(/foo \+ lib_m2/)
        assert_no_line_text(/def lib_m1/)

        # don't display frame that matches skip_path
        assert_line_text([
          /#0\s+block in <main> at/,
          /#2\s+<main> at/
        ])
        assert_no_line_text(/#1/)

        type 'c'

        # make sure the debugger and program can proceed normally
        type 'p "result: #{result.to_s}"'
        assert_line_text(/result: 3/)

        type 'c'
      end
    ensure
      File.unlink(lib_file)
    end
  end
end

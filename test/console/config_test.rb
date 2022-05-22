# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class SetTest < ConsoleTestCase
    def program
      <<~RUBY
        1| def foo
        2|   bar
        3| end
        4| def bar
        5|   p :bar
        6| end
        7| foo
      RUBY
    end

    def test_config_show
      debug_code(program) do
        type 'config'
        # show all configurations with descriptions
        assert_line_text([
          /show_src_lines = \d+/,
          /show_frames = \d+/
        ])
        # only show this configuration
        type 'config show_frames'
        assert_no_line_text(/show_src_lines/)
        assert_line_text([
          /show_frames = \d+/
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

  class ShowSrcLinesTest < ConsoleTestCase
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

  class ShowFramesTest < ConsoleTestCase
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

  class SkipPathTest < ConsoleTestCase
    def lib_file
      <<~RUBY
        def lib_m1
          yield
        end
        def lib_m2
          2
        end

        begin
          raise "raised in lib_file"
        rescue => e
          # rescue
        end
      RUBY
    end

    TEMPFILE_BASENAME = __FILE__.hash.abs.to_s(16)

    def program(lib_file)
      <<~RUBY
     1|
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

    def with_tempfile
      t = Tempfile.create([TEMPFILE_BASENAME, '.rb']).tap do |f|
        f.write(lib_file)
        f.close
      end
      yield t
    ensure
      File.unlink t if t
    end

    def debug_code
      with_tempfile do |lib_file|
        super program(lib_file)
      end
    end

    def test_skip_path_skip_frames_that_match_the_path
      debug_code do
        type "config set skip_path /#{TEMPFILE_BASENAME}/"
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
    end

    def test_skip_path_skip_tracer_output
      debug_code do
        type "config set skip_path /#{TEMPFILE_BASENAME}/"
        type 'trace line'
        type 'c'

        assert_no_line_text(/#{TEMPFILE_BASENAME}.*\.rb/)

        type 'c'
      end
    end

    def test_skip_path_skip_recording_the_frames
      debug_code do
        type "config set skip_path /#{TEMPFILE_BASENAME}/"
        type 'record on'
        type 'c'
        type 'record'
        assert_line_text(/5 records/)
        type 's back'
        type 's back'
        type 's back'
        type 's back'
        type 's back'
        assert_line_text(/foo \+ lib_m2/)
        assert_no_line_text(/def lib_m1/)

        type 'c'
      end
    end

    def test_skip_path_skip_catch_breakpoint
      # without skip_path
      debug_code do
        type 'catch RuntimeError'
        type 'c'
        assert_line_text(/RuntimeError/)
        type 'c'
        type 'c'
      end

      # with skip_path
      debug_code do
        type "config set skip_path /#{TEMPFILE_BASENAME}/"
        type 'catch RuntimeError'
        type 'c'
        assert_no_line_text(/RuntimeError/)
        type 'c'
      end
    end
  end

  class ConfigKeepAllocSiteTest < ConsoleTestCase
    def program
      <<~RUBY
         1| a = Object.new
         2| p a
      RUBY
    end

    def test_p_with_keep_alloc_site
      debug_code(program) do
        type 'config set keep_alloc_site true'
        assert_line_text([
          /keep_alloc_site = true/
        ])
        type 's'
        assert_line_num 2
        type 'p a'
        assert_line_text([
          /allocated at/
        ])
        type 'pp a'
        assert_line_text([
          /allocated at/
        ])
        type 'q!'
      end
    end
  end

  class LogLevelTest < ConsoleTestCase
    def program
      <<~RUBY
      1| a = 1
      RUBY
    end

    def test_debugger_takes_log_level_config_from_env_var
      # default WARN level doesn't report threads creation
      debug_code(program, remote: false) do
        type 'Thread.new {}.join'
        assert_no_line_text(/Thread #\d+ is created/)
        type 'c'
      end

      ENV["RUBY_DEBUG_LOG_LEVEL"] = "INFO"
      debug_code(program, remote: false) do
        type 'Thread.new {}.join'
        assert_line_text(/DEBUGGER \(INFO\): Thread #\d+ is created/)
        type 'c'
      end
    ensure
      ENV["RUBY_DEBUG_LOG_LEVEL"] = nil
    end

    def test_debugger_takes_log_level_config_from_config_option
      # default WARN level doesn't report threads creation
      debug_code(program, remote: false) do
        type 'Thread.new {}.join'
        assert_no_line_text(/Thread #\d+ is created/)
        type 'config set log_level INFO'
        type 'Thread.new {}.join'
        assert_line_text(/DEBUGGER \(INFO\): Thread #\d+ is created/)
        type 'c'
      end
    end
  end
end

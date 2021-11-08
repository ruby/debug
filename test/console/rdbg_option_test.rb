# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class DebugCommandOptionTest < ConsoleTestCase
    def program
      <<~RUBY
      1| raise "foo"
      RUBY
    end

    def test_debug_command_is_executed
      run_rdbg(program, options: "-e 'catch RuntimeError'") do
        type "c"
        assert_line_text(/Stop by #0  BP - Catch  "RuntimeError"/)
        type "q!"
      end
    end
  end

  class NonstopOptionTest < ConsoleTestCase
    def program
      <<~RUBY
      1| a = "foo"
      2| binding.b
      RUBY
    end

    def test_debugger_doesnt_stop
      run_rdbg(program, options: "--nonstop") do
        type "a + 'bar'"
        assert_line_text(/foobar/)
        type "c"
      end
    end
  end

  class StopAtLoadOptionTest < ConsoleTestCase
    def program
      <<~RUBY
      1| a = "foo"
      2| binding.b
      RUBY
    end

    def test_debugger_stops_immediately
      run_rdbg(program, options: "--stop-at-load") do
        # stops at the earliest possible location
        assert_line_text(/\[C\] Kernel#require/)
        type "c"
        type "a + 'bar'"
        assert_line_text(/foobar/)
        type "c"
      end
    end
  end

  class RCFileTest < ConsoleTestCase
    def rc_filename
      File.join(@pty_home_dir, ".rdbgrc")
    end

    def rc_script
      "config set skip_path /foo/bar/"
    end

    def program
      <<~RUBY
      1| a = 1
      RUBY
    end

    def with_rc_script
      File.open(rc_filename, "w") { |f| f.write(rc_script) }

      yield
    ensure
      File.delete(rc_filename)
    end

    def test_debugger_loads_the_rc_file_by_default
      with_rc_script do
        run_rdbg(program) do
          type "config skip_path"
          assert_line_text(/foo\\\/bar/)
          type "c"
        end
      end
    end

    def test_debugger_doesnt_load_the_rc_file_with_no_rc
      with_rc_script do
        run_rdbg(program, options: "--no-rc") do
          type "config skip_path"
          assert_no_line_text(/foo\\\/bar/)
          type "c"
        end
      end
    end
  end

  class InitScriptTest < ConsoleTestCase
    TEMPFILE_BASENAME = __FILE__.hash.abs.to_s(16)

    def with_init_script(filename)
      t = Tempfile.create(filename).tap do |f|
        f.write(init_script)
        f.close
      end
      yield t
    ensure
      File.unlink t if t
    end

    class CommandScriptTest < InitScriptTest
      def init_script
        <<~CMD
        catch RuntimeError
        CMD
      end

      def program
        <<~RUBY
        1| raise "foo"
        RUBY
      end

      def test_debugger_executes_the_file_as_commands
        with_init_script([TEMPFILE_BASENAME]) do |init_script|
          run_rdbg(program, options: "-x #{init_script.path}") do
            type "c"
            assert_line_text(/Stop by #0  BP - Catch  "RuntimeError"/)
            type "q!"
          end
        end
      end
    end

    class RubyScriptTest < InitScriptTest
      def init_script
        <<~CMD
        def foo
          "foo"
        end
        CMD
      end

      def program
        <<~RUBY
        1| 123
        RUBY
      end

      def test_debugger_executes_the_file_as_ruby
        with_init_script([TEMPFILE_BASENAME, ".rb"]) do |init_script|
          run_rdbg(program, options: "-x #{init_script.path}") do
            type "foo + 'bar'"
            assert_line_text(/foobar/)
            type "q!"
          end
        end
      end
    end
  end
end

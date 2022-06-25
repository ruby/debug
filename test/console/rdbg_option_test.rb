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

# frozen_string_literal: true
module DEBUGGER__
  class Console
    begin
      raise LoadError

      require 'reline'
      require_relative 'color'
      include Color

      def readline_setup prompt
        commands = DEBUGGER__.commands
        Reline.completion_proc = -> given do
          buff = Reline.line_buffer
          Reline.completion_append_character= ' '

          if /\s/ =~ buff # second parameters
            given = File.expand_path(given + 'a').sub(/a\z/, '')
            files = Dir.glob(given + '*')
            if files.size == 1 && File.directory?(files.first)
              Reline.completion_append_character= '/'
            end
            files
          else
            commands.grep(/\A#{given}/)
          end
        end

        Reline.output_modifier_proc = -> buff, **kw do
          c, rest = get_command buff
          if commands.include?(c)
            colorize(c, [:GREEN, :UNDERLINE]) + (rest ? colorize_code(rest) : '')
          else
            colorize_code(buff)
          end
        end
      end

      def get_command line
        if /\A([a-z]+)(\s.+)?$/ =~ line.strip
          return $1, $2
        else
          line
        end
      end

      def readline prompt = "(rdbg) "
        readline_setup prompt
        Reline.readmultiline(prompt, true){ true }
      end

    rescue LoadError
    begin
      require 'readline'

      def readline_setup
        Readline.completion_proc = proc{|given|
          buff = Readline.line_buffer
          Readline.completion_append_character= ' '

          if /\s/ =~ buff # second parameters
            given = File.expand_path(given + 'a').sub(/a\z/, '')
            files = Dir.glob(given + '*')
            if files.size == 1 && File.directory?(files.first)
              Readline.completion_append_character= '/'
            end
            files
          else
            DEBUGGER__.commands.grep(/\A#{given}/)
          end
        }
      end

      def readline
        readline_setup
        Readline.readline("(rdbg) ", true)
      end

    rescue LoadError
      def readline
        print "(rdbg) "
        gets
      end
    end
    end
  end
end


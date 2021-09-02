# frozen_string_literal: true
module DEBUGGER__
  class Console
    begin
      raise LoadError if CONFIG[:no_reline]
      require 'reline'

      # reline 0.2.7 or later is required.
      raise LoadError if Reline::VERSION < '0.2.6'

      require_relative 'color'
      include Color

      # 0.2.7 has SIGWINCH issue on non-main thread
      class ::Reline::LineEditor
        m = Module.new do
          def reset(prompt = '', encoding:)
            super
            Signal.trap(:SIGWINCH, nil)
          end
        end
        prepend m
      end

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
            commands.keys.grep(/\A#{given}/)
          end
        end

        Reline.output_modifier_proc = -> buff, **kw do
          c, rest = get_command buff

          case
          when commands.keys.include?(c = c.strip)
            # [:DIM, :CYAN, :BLUE, :CLEAR, :UNDERLINE, :REVERSE, :RED, :GREEN, :MAGENTA, :BOLD, :YELLOW]
            cmd = colorize(c.strip, [:CYAN, :UNDERLINE])

            if commands[c] == c
              rprompt = colorize("    # command", [:DIM])
            else
              rprompt = colorize("    # #{commands[c]} command", [:DIM])
            end

            rest = (rest ? colorize_code(rest) : '') + rprompt
            cmd + rest
          when !rest && /\A\s*[a-z]*\z/ =~ c
            buff
          else
            colorize_code(buff.chomp) + colorize("    # ruby", [:DIM])
          end
        end
      end

      private def get_command line
        case line.chomp
        when /\A(\s*[a-z]+)(\s.*)?\z$/
          return $1, $2
        else
          line.chomp
        end
      end

      def readline prompt
        readline_setup prompt
        Reline.readmultiline(prompt, true){ true }
      end

    rescue LoadError
    begin
      require 'readline.so'

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
            DEBUGGER__.commands.keys.grep(/\A#{given}/)
          end
        }
      end

      def readline prompt
        readline_setup
        Readline.readline(prompt, true)
      end

    rescue LoadError
      def readline prompt
        print prompt
        gets
      end
    end
    end
  end
end


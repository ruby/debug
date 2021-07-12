# frozen_string_literal: true

require_relative 'session'
return unless defined?(DEBUGGER__)

require 'io/console/size'

module DEBUGGER__
  class UI_Console < UI_Base
    def initialize
      unless CONFIG[:no_sigint_hook]
        @prev_handler = trap(:SIGINT){
          ThreadClient.current.on_trap :SIGINT
        }
      end

      @history_loaded = false
    end

    def close
      if @prev_handler
        trap(:SIGINT, @prev_handler)
      end
    end

    def remote?
      false
    end

    def width
      if (w = IO.console_size[1]) == 0 # for tests PTY
        80
      else
        w
      end
    end

    def quit n
      exit n
    end

    def ask prompt
      setup_interrupt do
        print prompt
        ($stdin.gets || '').strip
      end
    end

    def puts str = nil
      case str
      when Array
        str.each{|line|
          $stdout.puts line.chomp
        }
      when String
        str.each_line{|line|
          $stdout.puts line.chomp
        }
      when nil
        $stdout.puts
      end
    end

    begin
      require 'readline'

      at_exit{
        # Save
        path = File.expand_path(CONFIG[:history_file] || '~/.rdbg_history')
        open(path, 'w'){|f|
          Readline::HISTORY.each{|hist|
            next if hist.empty?
            f.puts hist
          }
        }
      }

      def readline_setup
        unless @history_loaded
          if File.exist?(f = File.expand_path(CONFIG[:history_file] || '~/.rdbg_history'))
            File.readlines(f).each{|line| line.strip!; Readline::HISTORY.push line unless line.empty?}
          end
          @history_loaded = true
        end

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

      def readline_body
        readline_setup
        Readline.readline("\n(rdbg) ", true)
      end
    rescue LoadError
      def readline_body
        print "\n(rdbg) "
        gets
      end
    end

    def readline
      setup_interrupt do
        (readline_body || 'quit').strip
      end
    end

    def setup_interrupt
      current_thread = Thread.current # should be session_server thread

      prev_handler = trap(:INT){
        current_thread.raise Interrupt
      }

      yield
    ensure
      trap(:INT, prev_handler)
    end
  end
end


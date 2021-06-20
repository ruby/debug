require_relative 'session'
return unless defined?(DEBUGGER__)

require 'io/console/size'

module DEBUGGER__
  class UI_Console < UI_Base
    def initialize
    end

    def remote?
      false
    end

    def width
      IO.console_size[1]
    end

    def quit n
      exit n
    end

    def ask prompt
      setup_interrupt do
        print prompt
        (gets || '').strip
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

  def self.set_prev_handler
    @prev_handler = trap(:SIGINT){
      ThreadClient.current.on_trap :SIGINT
    }
  end

  def self.stop_at_require
    set_config({})
    set_starter_breakpoint
    set_prev_handler
  end

  def self.console command: nil, **kw
    set_config(kw)

    if command
      cmds = command.split(";;")
      SESSION.add_initial_commands cmds
    end

    ::DEBUGGER__.add_line_breakpoint __FILE__, __LINE__ + 1, oneshot: true

    set_prev_handler
  end

  initialize_session(UI_Console.new)
end

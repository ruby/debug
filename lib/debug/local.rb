# frozen_string_literal: true

require 'io/console/size'
require_relative 'console'

module DEBUGGER__
  class UI_LocalConsole < UI_Base
    def initialize
      @console = Console.new

      unless CONFIG[:no_sigint_hook]
        @prev_handler = trap(:SIGINT){
          ThreadClient.current.on_trap :SIGINT
        }
      end
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

    def readline
      setup_interrupt do
        (@console.readline || 'quit').strip
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


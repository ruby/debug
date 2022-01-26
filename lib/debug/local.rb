# frozen_string_literal: true

require 'io/console/size'
require_relative 'console'

module DEBUGGER__
  class UI_LocalConsole < UI_Base
    def initialize
      @console = Console.new
    end

    def remote?
      false
    end

    def activate session, on_fork: false
      unless CONFIG[:no_sigint_hook]
        prev_handler = trap(:SIGINT){
          if session.active?
            ThreadClient.current.on_trap :SIGINT
          end
        }
        session.intercept_trap_sigint_start prev_handler
      end
    end

    def deactivate
      if SESSION.intercept_trap_sigint?
        prev = SESSION.intercept_trap_sigint_end
        trap(:SIGINT, prev)
      end

      @console.deactivate
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

    def puts_internal_test_info(internal_info)
      $stdout.puts("INTERNAL_INFO: #{internal_info}")
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

    def readline prompt = '(rdbg)'
      setup_interrupt do
        (@console.readline(prompt) || 'quit').strip
      end
    end

    def setup_interrupt
      SESSION.intercept_trap_sigint false do
        current_thread = Thread.current # should be session_server thread

        prev_handler = trap(:INT){
          current_thread.raise Interrupt
        }

        yield
      ensure
        trap(:INT, prev_handler)
      end
    end

    def after_fork_parent
      parent_pid = Process.pid

      at_exit{
        SESSION.intercept_trap_sigint_end
        trap(:SIGINT, :IGNORE)

        if Process.pid == parent_pid
          # only check child process from its parent
          begin
            # wait for all child processes to keep terminal
            Process.waitpid
          rescue Errno::ESRCH, Errno::ECHILD
          end
        end
      }
    end
  end

  class UI_LocalTuiConsole < UI_LocalConsole
    attr_reader :screen

    def initialize(windows)
      @screen = Screen.new(width, height, windows)
      super()
    end

    def deactivate
      super
      clear_screen!
    end

    def height
      if (w = IO.console_size[0]) == 0 # for tests PTY
        80
      else
        w
      end
    end

    def tui?
      true
    end

    def store_prev_line(line)
      @prev_line = line
    end

    def store_tui_data(data)
      @ui_data = data
    end

    def puts str = nil
      @screen.draw_windows(@ui_data)

      if @prev_line
        @screen.draw_repl(@prev_line)
        @prev_line = nil
      end

      @screen.draw_repl(str)
      @screen.render!
    end

    def windows_metadata
      @screen.windows_metadata
    end

    def clear_screen!
      @screen.clear_screen!
    end

    class Screen
      attr_reader :width, :height, :windows, :repl

      def initialize(width, height, windows)
        @height = height
        @width = width
        @windows = windows
        # we need to leave 1 line for the input and 1 line for overflow buffer
        @repl = REPL.new("REPL", @width, height - windows.sum(&:height) - 2)
        @windows << @repl
      end

      def render!
        clear_screen!
        @windows.each { |w| w.render!($stdout) }
      end

      def draw_windows(data)
        @windows.each { |w| w.draw(data) }
      end

      def draw_repl(str)
        case str
        when Array
          str.each{|line|
            @repl.puts line.chomp
          }
        when String
          str.each_line{|line|
            @repl.puts line.chomp
          }
        when nil
          @repl.puts
        end
      end

      def windows_metadata
        @windows.each_with_object({}) do |window, metadata|
          metadata[window.name] = { width: window.content_width, height: window.content_height }
        end
      end

      def clear_screen!
        $stdout.print("\033c")
      end
    end

    class Window
      attr_reader :name, :width, :height, :content_width, :content_height

      def initialize(name, width, height)
        @name = name
        @width = width
        @content_width = @width
        @height = height
        @content_height = @height
        @lines = []
      end

      def puts line = ""
        if @lines.length >= @content_height
          @lines.slice!(0)
        end

        # if the current line will break into multiple lines, we need to skip more lines for it. otherwise it'll affect the overall layout
        if line.length > @content_width
          n_lines = (line.length/@content_width.to_f).ceil

          start = 0
          n_lines.times do
            if @lines.length >= @content_height
              @lines.slice!(0)
            end

            @lines << line[start..(start + @content_width - 1)]
            start += @content_width
          end
        else
          @lines << line
        end
      end

      def draw(data)
        window_data = data[name]
        return unless window_data

        case window_data
        when String
          puts(window_data)
        when Array
          window_data.each do |d|
            puts(d)
          end
        else
          raise "unsupported window data type for window [#{name}]: #{data.class} (#{data})"
        end
      end

      def render!(io)
        @lines.each do |line|
          io.puts(line)
        end
      end

      def clear
        @lines.clear
      end
    end

    class FramedWindow < Window
      def initialize(name, width, height)
        super
        # border and padding
        @content_width = @width - 2
        # top and bottom border
        @content_height = @height - 2
      end

      def render!(io)
        io.puts(top_border)

        @content_height.times do |i|
          if line = @lines[i]
            io.puts("┃ " + line)
          else
            io.puts("┃")
          end
        end

        io.puts(bottom_border)
      end

      def draw(data)
        # framed windows doesn't preserve data
        clear
        super
      end

      private

      def top_border
        @top_border ||= begin
          head = "┏━━" + " (#{@name}) "
          tail = "━" * (@width - head.length)
          head + tail
        end
      end

      def bottom_border
        @bottom_border ||= "┗" + "━" * (@width - 1)
      end
    end

    class REPL < Window
    end
  end
end


# frozen_string_literal: true
module DEBUGGER__
  class Console
    COMPLETION_PROC = -> given do
      thread_client = SESSION.managed_thread_clients.first
      binding = thread_client.current_binding
      frame_self = thread_client.current_frame&.self

      if frame_self.nil?
        next DEBUGGER__.commands.keys.grep(/\A#{given}/)
      end

      candidates =
        case given
        when /\A@\w/
          frame_self.instance_variables
        when /\A[A-Z]/
          if frame_self.is_a?(Module)
            frame_self.constants
          else
            frame_self.class.constants
          end
        when /^::([A-Z][^:\.\(\)]*)$/
          # Absolute Constant or class methods
          receiver = $1
          candidates = Object.constants.collect{|m| m.to_s}
          candidates.grep(/^#{receiver}/).collect{|e| "::" + e}
        when /\A\w/
          binding.local_variables + frame_self.methods
        else
          DEBUGGER__.commands.keys.grep(/\A#{given}/)
        end

      candidates.map(&:to_s)
    end

    begin
      raise LoadError if CONFIG[:no_reline]
      require 'reline'

      # reline 0.2.7 or later is required.
      raise LoadError if Reline::VERSION < '0.2.7'

      require_relative 'color'
      include Color

      begin
        prev = trap(:SIGWINCH, nil)
        trap(:SIGWINCH, prev)
        SIGWINCH_SUPPORTED = true
      rescue ArgumentError
        SIGWINCH_SUPPORTED = false
      end

      # 0.2.7 has SIGWINCH issue on non-main thread
      class ::Reline::LineEditor
        m = Module.new do
          def reset(prompt = '', encoding:)
            super
            Signal.trap(:SIGWINCH, nil)
          end
        end
        prepend m
      end if SIGWINCH_SUPPORTED

      def readline_setup prompt
        load_history_if_not_loaded
        Reline.completion_proc = COMPLETION_PROC

        commands = DEBUGGER__.commands

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

      def history
        Reline::HISTORY
      end

    rescue LoadError
      begin
        require 'readline.so'

        def readline_setup
          load_history_if_not_loaded
          Readline.completion_proc = COMPLETION_PROC
        end

        def readline prompt
          readline_setup
          Readline.readline(prompt, true)
        end

        def history
          Readline::HISTORY
        end

      rescue LoadError
        def readline prompt
          print prompt
          gets
        end

        def history
          nil
        end
      end
    end

    def history_file
      CONFIG[:history_file] || File.expand_path("~/.rdbg_history")
    end

    FH = "# Today's OMIKUJI: "

    def read_history_file
      if history && File.exists?(path = history_file)
        f = (['', 'DAI-', 'CHU-', 'SHO-'].map{|e| e+'KICHI'}+['KYO']).sample
        ["#{FH}#{f}".dup] + File.readlines(path)
      else
        []
      end
    end

    def initialize
      @init_history_lines = nil
    end

    def load_history_if_not_loaded
      return if @init_history_lines

      @init_history_lines = load_history
    end

    def deactivate
      if history && @init_history_lines
        added_records = history.to_a[@init_history_lines .. -1]
        path = history_file
        max = CONFIG[:save_history] || 10_000

        if !added_records.empty? && !path.empty?
          orig_records = read_history_file
          open(history_file, 'w'){|f|
            (orig_records + added_records).last(max).each{|line|
              if !line.start_with?(FH) && !line.strip.empty?
                f.puts line.strip
              end
            }
          }
        end
      end
    end

    def load_history
      read_history_file.count{|line|
        line.strip!
        history << line unless line.empty?
      }
    end
  end # class Console
end


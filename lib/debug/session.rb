# frozen_string_literal: true

# skip to load debugger for bundle exec

if $0.end_with?('bin/bundle') && ARGV.first == 'exec'
  trace_var(:$0) do |file|
    trace_var(:$0, nil)
    if /-r (#{__dir__}\S+)/ =~ ENV['RUBYOPT']
      lib = $1
      $LOADED_FEATURES.delete_if{|path| path.start_with?(__dir__)}
      ENV['RUBY_DEBUG_INITIAL_SUSPEND_PATH'] = file
      require lib
      ENV['RUBY_DEBUG_INITIAL_SUSPEND_PATH'] = nil
    end
  end

  return
end

require_relative 'config'
require_relative 'thread_client'
require_relative 'source_repository'
require_relative 'breakpoint'
require_relative 'tracer'

# To prevent loading old lib/debug.rb in Ruby 2.6 to 3.0
$LOADED_FEATURES << 'debug.rb'
require 'debug' # invalidate the $LOADED_FEATURE cache

require 'json' if ENV['RUBY_DEBUG_TEST_MODE']

class RubyVM::InstructionSequence
  def traceable_lines_norec lines
    code = self.to_a[13]
    line = 0
    code.each{|e|
      case e
      when Integer
        line = e
      when Symbol
        if /\ARUBY_EVENT_/ =~ e.to_s
          lines[line] = [e, *lines[line]]
        end
      end
    }
  end

  def traceable_lines_rec lines
    self.each_child{|ci| ci.traceable_lines_rec(lines)}
    traceable_lines_norec lines
  end

  def type
    self.to_a[9]
  end

  def argc
    self.to_a[4][:arg_size]
  end

  def locals
    self.to_a[10]
  end

  def last_line
    self.to_a[4][:code_location][2]
  end

  def first_line
    self.to_a[4][:code_location][0]
  end
end

module DEBUGGER__
  PresetCommand = Struct.new(:commands, :source, :auto_continue)
  class PostmortemError < RuntimeError; end

  class Session
    def initialize ui
      @ui = ui
      @sr = SourceRepository.new
      @bps = {} # bp.key => bp
                #   [file, line] => LineBreakpoint
                #   "Error" => CatchBreakpoint
                #   "Foo#bar" => MethodBreakpoint
                #   [:watch, ivar] => WatchIVarBreakpoint
                #   [:check, expr] => CheckBreakpoint
      #
      @tracers = []
      @th_clients = nil # {Thread => ThreadClient}
      @q_evt = Queue.new
      @displays = []
      @tc = nil
      @tc_id = 0
      @preset_command = nil
      @postmortem_hook = nil
      @postmortem = false
      @thread_stopper = nil
      @intercept_trap_sigint = false
      @intercepted_sigint_cmd = 'DEFAULT'

      @frame_map = {} # {id => [threadId, frame_depth]} for DAP
      @var_map   = {1 => [:globals], } # {id => ...} for DAP
      @src_map   = {} # {id => src}

      @tp_load_script = TracePoint.new(:script_compiled){|tp|
        ThreadClient.current.on_load tp.instruction_sequence, tp.eval_script
      }
      @tp_load_script.enable

      activate
    end

    def active?
      !@q_evt.closed?
    end

    def break_at? file, line
      @bps.has_key? [file, line]
    end

    def check_forked
      unless active?
        # TODO: Support it
        raise 'DEBUGGER: stop at forked process is not supported yet.'
      end
    end

    def activate on_fork: false
      @session_server = Thread.new do
        Thread.current.name = 'DEBUGGER__::SESSION@server'
        Thread.current.abort_on_exception = true
        session_server_main
      end

      setup_threads

      thc = thread_client @session_server
      thc.is_management

      if on_fork
        @tp_thread_begin.disable
        @tp_thread_begin = nil
        @ui.activate self, on_fork: true
      else
        @ui.activate self, on_fork: false
      end

      if @ui.respond_to?(:reader_thread) && thc = thread_client(@ui.reader_thread)
        thc.is_management
      end

      @tp_thread_begin = TracePoint.new(:thread_begin){|tp|
        th = Thread.current
        ThreadClient.current.on_thread_begin th
      }
      @tp_thread_begin.enable
    end

    def deactivate
      thread_client.deactivate
      @thread_stopper.disable if @thread_stopper
      @tp_load_script.disable
      @tp_thread_begin.disable
      @bps.each{|k, bp| bp.disable}
      @th_clients.each{|th, thc| thc.close}
      @tracers.each{|t| t.disable}
      @q_evt.close
      @ui&.deactivate
      @ui = nil
    end

    def reset_ui ui
      @ui.deactivate
      @ui = ui
    end

    def pop_event
      @q_evt.pop
    end

    def session_server_main
      while evt = pop_event
        # variable `@internal_info` is only used for test
        tc, output, ev, @internal_info, *ev_args = evt
        output.each{|str| @ui.puts str}

        case ev
        when :init
          wait_command_loop tc

        when :load
          iseq, src = ev_args
          on_load iseq, src
          @ui.event :load
          tc << :continue

        when :trace
          trace_id, msg = ev_args
          if t = @tracers.find{|t| t.object_id == trace_id}
            t.puts msg
          end
          tc << :continue

        when :thread_begin
          th = ev_args.shift
          on_thread_begin th
          @ui.event :thread_begin, th
          tc << :continue

        when :suspend
          case ev_args.first
          when :breakpoint
            bp, i = bp_index ev_args[1]
            @ui.event :suspend_bp, i, bp
          when :trap
            @ui.event :suspend_trap, sig = ev_args[1]

            if sig == :SIGINT && (@intercepted_sigint_cmd.kind_of?(Proc) || @intercepted_sigint_cmd.kind_of?(String))
              @ui.puts "#{@intercepted_sigint_cmd.inspect} is registerred as SIGINT handler."
              @ui.puts "`sigint` command execute it."
            end
          else
            @ui.event :suspended
          end

          if @displays.empty?
            stop_all_threads
            wait_command_loop tc
          else
            tc << [:eval, :display, @displays]
          end

        when :result
          case ev_args.first
          when :try_display
            failed_results = ev_args[1]
            if failed_results.size > 0
              i, _msg = failed_results.last
              if i+1 == @displays.size
                @ui.puts "canceled: #{@displays.pop}"
              end
            end
            stop_all_threads

          when :method_breakpoint, :watch_breakpoint
            bp = ev_args[1]
            if bp
              add_bp(bp)
              show_bps bp
            else
              # can't make a bp
            end
          when :trace_pass
            obj_id = ev_args[1]
            obj_inspect = ev_args[2]
            opt = ev_args[3]
            @tracers << t = ObjectTracer.new(@ui, obj_id, obj_inspect, **opt)
            @ui.puts "Enable #{t.to_s}"
          else
            # ignore
          end

          wait_command_loop tc

        when :dap_result
          dap_event ev_args # server.rb
          wait_command_loop tc
        end
      end
    ensure
      deactivate
    end

    def add_preset_commands name, cmds, kick: true, continue: true
      cs = cmds.map{|c|
        c.each_line.map{|line|
          line = line.strip.gsub(/\A\s*\#.*/, '').strip
          line unless line.empty?
        }.compact
      }.flatten.compact

      if @preset_command && !@preset_command.commands.empty?
        @preset_command.commands += cs
      else
        @preset_command = PresetCommand.new(cs, name, continue)
      end

      ThreadClient.current.on_init name if kick
    end

    def source iseq
      if !CONFIG[:no_color]
        @sr.get_colored(iseq)
      else
        @sr.get(iseq)
      end
    end

    def inspect
      "DEBUGGER__::SESSION"
    end

    def wait_command_loop tc
      @tc = tc

      loop do
        case wait_command
        when :retry
          # nothing
        else
          break
        end
      rescue Interrupt
        @ui.puts "\n^C"
        retry
      end
    end

    def prompt
      if @postmortem
        '(rdbg:postmortem) '
      else
        '(rdbg) '
      end
    end

    def wait_command
      if @preset_command
        if @preset_command.commands.empty?
          if @preset_command.auto_continue
            @preset_command = nil

            @tc << :continue
            restart_all_threads
            return
          else
            @preset_command = nil
            return :retry
          end
        else
          line = @preset_command.commands.shift
          @ui.puts "(rdbg:#{@preset_command.source}) #{line}"
        end
      else
        @ui.puts "INTERNAL_INFO: #{JSON.generate(@internal_info)}" if ENV['RUBY_DEBUG_TEST_MODE']
        line = @ui.readline prompt
      end

      case line
      when String
        process_command line
      when Hash
        process_dap_request line # defined in server.rb
      else
        raise "unexpected input: #{line.inspect}"
      end
    end

    def process_command line
      if line.empty?
        if @repl_prev_line
          line = @repl_prev_line
        else
          return :retry
        end
      else
        @repl_prev_line = line
      end

      /([^\s]+)(?:\s+(.+))?/ =~ line
      cmd, arg = $1, $2

      # p cmd: [cmd, *arg]

      case cmd
      ### Control flow

      # * `s[tep]`
      #   * Step in. Resume the program until next breakable point.
      # * `s[tep] <n>`
      #   * Step in, resume the program at `<n>`th breakable point.
      when 's', 'step'
        cancel_auto_continue
        check_postmortem
        step_command :in, arg

      # * `n[ext]`
      #   * Step over. Resume the program until next line.
      # * `n[ext] <n>`
      #   * Step over, same as `step <n>`.
      when 'n', 'next'
        cancel_auto_continue
        check_postmortem
        step_command :next, arg

      # * `fin[ish]`
      #   * Finish this frame. Resume the program until the current frame is finished.
      # * `fin[ish] <n>`
      #   * Finish frames, same as `step <n>`.
      when 'fin', 'finish'
        cancel_auto_continue
        check_postmortem
        step_command :finish, arg

      # * `c[ontinue]`
      #   * Resume the program.
      when 'c', 'continue'
        cancel_auto_continue
        @tc << :continue
        restart_all_threads

      # * `q[uit]` or `Ctrl-D`
      #   * Finish debugger (with the debuggee process on non-remote debugging).
      when 'q', 'quit'
        if ask 'Really quit?'
          @ui.quit arg.to_i
          @tc << :continue
          restart_all_threads
        else
          return :retry
        end

      # * `q[uit]!`
      #   * Same as q[uit] but without the confirmation prompt.
      when 'q!', 'quit!'
        @ui.quit arg.to_i
        restart_all_threads

      # * `kill`
      #   * Stop the debuggee process with `Kernal#exit!`.
      when 'kill'
        if ask 'Really kill?'
          exit! (arg || 1).to_i
        else
          return :retry
        end

      # * `kill!`
      #   * Same as kill but without the confirmation prompt.
      when 'kill!'
        exit! (arg || 1).to_i

      # * `sigint`
      #   * Execute SIGINT handler registerred by the debuggee.
      #   * Note that this command should be used just after stop by `SIGINT`.
      when 'sigint'
        begin
          case cmd = @intercepted_sigint_cmd
          when nil, 'IGNORE', :IGNORE, 'DEFAULT', :DEFAULT
            # ignore
          when String
            eval(cmd)
          when Proc
            cmd.call
          end

          @tc << :continue
          restart_all_threads

        rescue Exception => e
          @ui.puts "Exception: #{e}"
          @ui.puts e.backtrace.map{|line| "  #{e}"}
          return :retry
        end

      ### Breakpoint

      # * `b[reak]`
      #   * Show all breakpoints.
      # * `b[reak] <line>`
      #   * Set breakpoint on `<line>` at the current frame's file.
      # * `b[reak] <file>:<line>` or `<file> <line>`
      #   * Set breakpoint on `<file>:<line>`.
      # * `b[reak] <class>#<name>`
      #    * Set breakpoint on the method `<class>#<name>`.
      # * `b[reak] <expr>.<name>`
      #    * Set breakpoint on the method `<expr>.<name>`.
      # * `b[reak] ... if: <expr>`
      #   * break if `<expr>` is true at specified location.
      # * `b[reak] ... pre: <command>`
      #   * break and run `<command>` before stopping.
      # * `b[reak] ... do: <command>`
      #   * break and run `<command>`, and continue.
      # * `b[reak] if: <expr>`
      #   * break if: `<expr>` is true at any lines.
      #   * Note that this feature is super slow.
      when 'b', 'break'
        check_postmortem

        if arg == nil
          show_bps
          return :retry
        else
          case bp = repl_add_breakpoint(arg)
          when :noretry
          when nil
            return :retry
          else
            show_bps bp
            return :retry
          end
        end

      # skip
      when 'bv'
        check_postmortem
        require 'json'

        h = Hash.new{|h, k| h[k] = []}
        @bps.each{|key, bp|
          if LineBreakpoint === bp
            h[bp.path] << {lnum: bp.line}
          end
        }
        if h.empty?
          # TODO: clean?
        else
          open(".rdb_breakpoints.json", 'w'){|f| JSON.dump(h, f)}
        end

        vimsrc = File.join(__dir__, 'bp.vim')
        system("vim -R -S #{vimsrc} #{@tc.location.path}")

        if File.exist?(".rdb_breakpoints.json")
          pp JSON.load(File.read(".rdb_breakpoints.json"))
        end

        return :retry

      # * `catch <Error>`
      #   * Set breakpoint on raising `<Error>`.
      when 'catch'
        check_postmortem

        if arg
          bp = repl_add_catch_breakpoint arg
          show_bps bp if bp
        else
          show_bps
        end
        return :retry

      # * `watch @ivar`
      #   * Stop the execution when the result of current scope's `@ivar` is changed.
      #   * Note that this feature is super slow.
      when 'wat', 'watch'
        check_postmortem

        if arg && arg.match?(/\A@\w+/)
          @tc << [:breakpoint, :watch, arg]
        else
          show_bps
          return :retry
        end

      # * `del[ete]`
      #   * delete all breakpoints.
      # * `del[ete] <bpnum>`
      #   * delete specified breakpoint.
      when 'del', 'delete'
        check_postmortem

        bp =
        case arg
        when nil
          show_bps
          if ask "Remove all breakpoints?", 'N'
            delete_bp
          end
        when /\d+/
          delete_bp arg.to_i
        else
          nil
        end
        @ui.puts "deleted: \##{bp[0]} #{bp[1]}" if bp
        return :retry

      ### Information

      # * `bt` or `backtrace`
      #   * Show backtrace (frame) information.
      # * `bt <num>` or `backtrace <num>`
      #   * Only shows first `<num>` frames.
      # * `bt /regexp/` or `backtrace /regexp/`
      #   * Only shows frames with method name or location info that matches `/regexp/`.
      # * `bt <num> /regexp/` or `backtrace <num> /regexp/`
      #   * Only shows first `<num>` frames with method name or location info that matches `/regexp/`.
      when 'bt', 'backtrace'
        case arg
        when /\A(\d+)\z/
          @tc << [:show, :backtrace, arg.to_i, nil]
        when /\A\/(.*)\/\z/
          pattern = $1
          @tc << [:show, :backtrace, nil, Regexp.compile(pattern)]
        when /\A(\d+)\s+\/(.*)\/\z/
          max, pattern = $1, $2
          @tc << [:show, :backtrace, max.to_i, Regexp.compile(pattern)]
        else
          @tc << [:show, :backtrace, nil, nil]
        end

      # * `l[ist]`
      #   * Show current frame's source code.
      #   * Next `list` command shows the successor lines.
      # * `l[ist] -`
      #   * Show predecessor lines as opposed to the `list` command.
      # * `l[ist] <start>` or `l[ist] <start>-<end>`
      #   * Show current frame's source code from the line <start> to <end> if given.
      when 'l', 'list'
        case arg ? arg.strip : nil
        when /\A(\d+)\z/
          @tc << [:show, :list, {start_line: arg.to_i - 1}]
        when /\A-\z/
          @tc << [:show, :list, {dir: -1}]
        when /\A(\d+)-(\d+)\z/
          @tc << [:show, :list, {start_line: $1.to_i - 1, end_line: $2.to_i}]
        when nil
          @tc << [:show, :list]
        else
          @ui.puts "Can not handle list argument: #{arg}"
          return :retry
        end

      # * `edit`
      #   * Open the current file on the editor (use `EDITOR` environment variable).
      #   * Note that edited file will not be reloaded.
      # * `edit <file>`
      #   * Open <file> on the editor.
      when 'edit'
        if @ui.remote?
          @ui.puts "not supported on the remote console."
          return :retry
        end

        begin
          arg = resolve_path(arg) if arg
        rescue Errno::ENOENT
          @ui.puts "not found: #{arg}"
          return :retry
        end

        @tc << [:show, :edit, arg]

      # * `i[nfo]`
      #    * Show information about current frame (local/instance variables and defined constants).
      # * `i[nfo] l[ocal[s]]`
      #   * Show information about the current frame (local variables)
      #   * It includes `self` as `%self` and a return value as `%return`.
      # * `i[nfo] i[var[s]]` or `i[nfo] instance`
      #   * Show information about instance variables about `self`.
      # * `i[nfo] c[onst[s]]` or `i[nfo] constant[s]`
      #   * Show information about accessible constants except toplevel constants.
      # * `i[nfo] g[lobal[s]]`
      #   * Show information about global variables
      # * `i[nfo] ... </pattern/>`
      #   * Filter the output with `</pattern/>`.
      # * `i[nfo] th[read[s]]`
      #   * Show all threads (same as `th[read]`).
      when 'i', 'info'
        if /\/(.+)\/\z/ =~ arg
          pat = Regexp.compile($1)
          sub = $~.pre_match.strip
        else
          sub = arg
        end

        case sub
        when nil
          @tc << [:show, :default, pat] # something useful
        when 'l', /^locals?/
          @tc << [:show, :locals, pat]
        when 'i', /^ivars?/i, /^instance[_ ]variables?/i
          @tc << [:show, :ivars, pat]
        when 'c', /^consts?/i, /^constants?/i
          @tc << [:show, :consts, pat]
        when 'g', /^globals?/i, /^global[_ ]variables?/i
          @tc << [:show, :globals, pat]
        when 'th', /threads?/
          thread_list
          return :retry
        else
          @ui.puts "unrecognized argument for info command: #{arg}"
          show_help 'info'
          return :retry
        end

      # * `o[utline]` or `ls`
      #   * Show you available methods, constants, local variables, and instance variables in the current scope.
      # * `o[utline] <expr>` or `ls <expr>`
      #   * Show you available methods and instance variables of the given object.
      #   * If the object is a class/module, it also lists its constants.
      when 'outline', 'o', 'ls'
        @tc << [:show, :outline, arg]

      # * `display`
      #   * Show display setting.
      # * `display <expr>`
      #   * Show the result of `<expr>` at every suspended timing.
      when 'display'
        if arg && !arg.empty?
          @displays << arg
          @tc << [:eval, :try_display, @displays]
        else
          @tc << [:eval, :display, @displays]
        end

      # * `undisplay`
      #   * Remove all display settings.
      # * `undisplay <displaynum>`
      #   * Remove a specified display setting.
      when 'undisplay'
        case arg
        when /(\d+)/
          if @displays[n = $1.to_i]
            @displays.delete_at n
          end
          @tc << [:eval, :display, @displays]
        when nil
          if ask "clear all?", 'N'
            @displays.clear
          end
        end
        return :retry

      ### Frame control

      # * `f[rame]`
      #   * Show the current frame.
      # * `f[rame] <framenum>`
      #   * Specify a current frame. Evaluation are run on specified frame.
      when 'frame', 'f'
        @tc << [:frame, :set, arg]

      # * `up`
      #   * Specify the upper frame.
      when 'up'
        @tc << [:frame, :up]

      # * `down`
      #   * Specify the lower frame.
      when 'down'
        @tc << [:frame, :down]

      ### Evaluate

      # * `p <expr>`
      #   * Evaluate like `p <expr>` on the current frame.
      when 'p'
        @tc << [:eval, :p, arg.to_s]

      # * `pp <expr>`
      #   * Evaluate like `pp <expr>` on the current frame.
      when 'pp'
        @tc << [:eval, :pp, arg.to_s]

      # * `eval <expr>`
      #   * Evaluate `<expr>` on the current frame.
      when 'eval', 'call'
        if arg == nil || arg.empty?
          show_help 'eval'
          @ui.puts "\nTo evaluate the variable `#{cmd}`, use `pp #{cmd}` instead."
          return :retry
        else
          @tc << [:eval, :call, arg]
        end

      # * `irb`
      #   * Invoke `irb` on the current frame.
      when 'irb'
        if @ui.remote?
          @ui.puts "not supported on the remote console."
          return :retry
        end
        @tc << [:eval, :call, 'binding.irb']

        # don't repeat irb command
        @repl_prev_line = nil

      ### Trace
      # * `trace`
      #   * Show available tracers list.
      # * `trace line`
      #   * Add a line tracer. It indicates line events.
      # * `trace call`
      #   * Add a call tracer. It indicate call/return events.
      # * `trace exception`
      #   * Add an exception tracer. It indicates raising exceptions.
      # * `trace object <expr>`
      #   * Add an object tracer. It indicates that an object by `<expr>` is passed as a parameter or a receiver on method call.
      # * `trace ... </pattern/>`
      #   * Indicates only matched events to `</pattern/>` (RegExp).
      # * `trace ... into: <file>`
      #   * Save trace information into: `<file>`.
      # * `trace off <num>`
      #   * Disable tracer specified by `<num>` (use `trace` command to check the numbers).
      # * `trace off [line|call|pass]`
      #   * Disable all tracers. If `<type>` is provided, disable specified type tracers.
      when 'trace'
        if (re = /\s+into:\s*(.+)/) =~ arg
          into = $1
          arg.sub!(re, '')
        end

        if (re = /\s\/(.+)\/\z/) =~ arg
          pattern = $1
          arg.sub!(re, '')
        end

        case arg
        when nil
          @ui.puts 'Tracers:'
          @tracers.each_with_index{|t, i|
            @ui.puts "* \##{i} #{t}"
          }
          @ui.puts
          return :retry

        when /\Aline\z/
          @tracers << t = LineTracer.new(@ui, pattern: pattern, into: into)
          @ui.puts "Enable #{t.to_s}"
          return :retry

        when /\Acall\z/
          @tracers << t = CallTracer.new(@ui, pattern: pattern, into: into)
          @ui.puts "Enable #{t.to_s}"
          return :retry

        when /\Aexception\z/
          @tracers << t = ExceptionTracer.new(@ui, pattern: pattern, into: into)
          @ui.puts "Enable #{t.to_s}"
          return :retry

        when /\Aobject\s+(.+)/
          @tc << [:trace, :object, $1.strip, {pattern: pattern, into: into}]

        when /\Aoff\s+(\d+)\z/
          if t = @tracers[$1.to_i]
            t.disable
            @ui.puts "Disable #{t.to_s}"
          else
            @ui.puts "Unmatched: #{$1}"
          end
          return :retry

        when /\Aoff(\s+(line|call|exception|object))?\z/
          @tracers.each{|t|
            if $2.nil? || t.type == $2
              t.disable
              @ui.puts "Disable #{t.to_s}"
            end
          }
          return :retry

        else
          @ui.puts "Unknown trace option: #{arg.inspect}"
          return :retry
        end

      # Record
      # * `record`
      #   * Show recording status.
      # * `record [on|off]`
      #   * Start/Stop recording.
      # * `step back`
      #   * Start replay. Step back with the last execution log.
      #   * `s[tep]` does stepping forward with the last log.
      # * `step reset`
      #   * Stop replay .
      when 'record'
        case arg
        when nil, 'on', 'off'
          @tc << [:record, arg&.to_sym]
        else
          @ui.puts "unknown command: #{arg}"
          return :retry
        end

      ### Thread control

      # * `th[read]`
      #   * Show all threads.
      # * `th[read] <thnum>`
      #   * Switch thread specified by `<thnum>`.
      when 'th', 'thread'
        case arg
        when nil, 'list', 'l'
          thread_list
        when /(\d+)/
          thread_switch $1.to_i
        else
          @ui.puts "unknown thread command: #{arg}"
        end
        return :retry

      ### Configuration
      # * `config`
      #   * Show all configuration with description.
      # * `config <name>`
      #   * Show current configuration of <name>.
      # * `config set <name> <val>` or `config <name> = <val>`
      #   * Set <name> to <val>.
      # * `config append <name> <val>` or `config <name> << <val>`
      #   * Append `<val>` to `<name>` if it is an array.
      # * `config unset <name>`
      #   * Set <name> to default.
      when 'config'
        config_command arg
        return :retry

      # * `source <file>`
      #   * Evaluate lines in `<file>` as debug commands.
      when 'source'
        if arg
          begin
            cmds = File.readlines(path = File.expand_path(arg))
            add_preset_commands path, cmds, kick: true, continue: false
          rescue Errno::ENOENT
            @ui.puts "File not found: #{arg}"
          end
        else
          show_help 'source'
        end
        return :retry

      ### Help

      # * `h[elp]`
      #   * Show help for all commands.
      # * `h[elp] <command>`
      #   * Show help for the given command.
      when 'h', 'help', '?'
        if arg
          show_help arg
        else
          @ui.puts DEBUGGER__.help
        end
        return :retry

      ### END
      else
        @tc << [:eval, :pp, line]
=begin
        @repl_prev_line = nil
        @ui.puts "unknown command: #{line}"
        begin
          require 'did_you_mean'
          spell_checker = DidYouMean::SpellChecker.new(dictionary: DEBUGGER__.commands)
          correction = spell_checker.correct(line.split(/\s/).first || '')
          @ui.puts "Did you mean? #{correction.join(' or ')}" unless correction.empty?
        rescue LoadError
          # Don't use D
        end
        return :retry
=end
      end

    rescue Interrupt
      return :retry
    rescue SystemExit
      raise
    rescue PostmortemError => e
      @ui.puts e.message
      return :retry
    rescue Exception => e
      @ui.puts "[REPL ERROR] #{e.inspect}"
      @ui.puts e.backtrace.map{|e| '  ' + e}
      return :retry
    end

    def step_command type, arg
      case arg
      when nil
        @tc << [:step, type]
        restart_all_threads
      when /\A\d+\z/
        @tc << [:step, type, arg.to_i]
        restart_all_threads
      when /\Aback\z/, /\Areset\z/
        if type != :in
          @ui.puts "only `step #{arg}` is supported."
          :retry
        else
          @tc << [:step, arg.to_sym]
        end
      else
        @ui.puts "Unknown option: #{arg}"
        :retry
      end
    end

    def config_show key
      key = key.to_sym
      if CONFIG_SET[key]
        v = CONFIG[key]
        kv = "#{key} = #{v.nil? ? '(default)' : v.inspect}"
        desc = CONFIG_SET[key][1]
        line = "%-30s \# %s" % [kv, desc]
        if line.size > SESSION.width
          @ui.puts "\# #{desc}\n#{kv}"
        else
          @ui.puts line
        end
      else
        @ui.puts "Unknown configuration: #{key}. 'config' shows all configurations."
      end
    end

    def config_set key, val, append: false
      if CONFIG_SET[key = key.to_sym]
        begin
          if append
            CONFIG.append_config(key, val)
          else
            CONFIG[key] = val
          end
        rescue => e
          @ui.puts e.message
        end
      end

      config_show key
    end

    def config_command arg
      case arg
      when nil
        CONFIG_SET.each do |k, _|
          config_show k
        end

      when /\Aunset\s+(.+)\z/
        if CONFIG_SET[key = $1.to_sym]
          CONFIG[key] = nil
        end
        config_show key

      when /\A(\w+)\s*=\s*(.+)\z/
        config_set $1, $2

      when /\A\s*set\s+(\w+)\s+(.+)\z/
        config_set $1, $2

      when /\A(\w+)\s*<<\s*(.+)\z/
        config_set $1, $2, append: true

      when /\A\s*append\s+(\w+)\s+(.+)\z/
        config_set $1, $2

      when /\A(\w+)\z/
        config_show $1

      else
        @ui.puts "Can not parse parameters: #{arg}"
      end
    end


    def cancel_auto_continue
      if @preset_command&.auto_continue
        @preset_command.auto_continue = false
      end
    end

    def show_help arg
      DEBUGGER__.helps.each{|cat, cs|
        cs.each{|ws, desc|
          if ws.include? arg
            @ui.puts desc
            return
          end
        }
      }
      @ui.puts "not found: #{arg}"
    end

    def ask msg, default = 'Y'
      opts = '[y/n]'.tr(default.downcase, default)
      input = @ui.ask("#{msg} #{opts} ")
      input = default if input.empty?
      case input
      when 'y', 'Y'
        true
      else
        false
      end
    end

    # breakpoint management

    def iterate_bps
      deleted_bps = []
      i = 0
      @bps.each{|key, bp|
        if !bp.deleted?
          yield key, bp, i
          i += 1
        else
          deleted_bps << bp
        end
      }
    ensure
      deleted_bps.each{|bp| @bps.delete bp}
    end

    def show_bps specific_bp = nil
      iterate_bps do |key, bp, i|
        @ui.puts "#%d %s" % [i, bp.to_s] if !specific_bp || bp == specific_bp
      end
    end

    def bp_index specific_bp_key
      iterate_bps do |key, bp, i|
        if key == specific_bp_key
          return [bp, i]
        end
      end
      nil
    end

    def rehash_bps
      bps = @bps.values
      @bps.clear
      bps.each{|bp|
        add_bp bp
      }
    end

    def add_bp bp
      # don't repeat commands that add breakpoints
      @repl_prev_line = nil

      if @bps.has_key? bp.key
        unless bp.duplicable?
          @ui.puts "duplicated breakpoint: #{bp}"
          bp.disable
        end
      else
        @bps[bp.key] = bp
      end
    end

    def delete_bp arg = nil
      case arg
      when nil
        @bps.each{|key, bp| bp.delete}
        @bps.clear
      else
        del_bp = nil
        iterate_bps{|key, bp, i| del_bp = bp if i == arg}
        if del_bp
          del_bp.delete
          @bps.delete del_bp.key
          return [arg, del_bp]
        end
      end
    end

    BREAK_KEYWORDS = %w(if: do: pre:).freeze

    def parse_break arg
      mode = :sig
      expr = Hash.new{|h, k| h[k] = []}
      arg.split(' ').each{|w|
        if BREAK_KEYWORDS.any?{|pat| w == pat}
          mode = w[0..-2].to_sym
        else
          expr[mode] << w
        end
      }
      expr.default_proc = nil
      expr.transform_values{|v| v.join(' ')}
    end

    def repl_add_breakpoint arg
      expr = parse_break arg.strip
      cond = expr[:if]
      cmd = ['break', expr[:pre], expr[:do]] if expr[:pre] || expr[:do]

      case expr[:sig]
      when /\A(\d+)\z/
        add_line_breakpoint @tc.location.path, $1.to_i, cond: cond, command: cmd
      when /\A(.+)[:\s+](\d+)\z/
        add_line_breakpoint $1, $2.to_i, cond: cond, command: cmd
      when /\A(.+)([\.\#])(.+)\z/
        @tc << [:breakpoint, :method, $1, $2, $3, cond, cmd]
        return :noretry
      when nil
        add_check_breakpoint cond
      else
        @ui.puts "Unknown breakpoint format: #{arg}"
        @ui.puts
        show_help 'b'
      end
    end

    def repl_add_catch_breakpoint arg
      expr = parse_break arg.strip
      cond = expr[:if]
      cmd = ['catch', expr[:pre], expr[:do]] if expr[:pre] || expr[:do]

      bp = CatchBreakpoint.new(expr[:sig], cond: cond, command: cmd)
      add_bp bp
    end

    def add_catch_breakpoint pat
      bp = CatchBreakpoint.new(pat)
      add_bp bp
    end

    def add_check_breakpoint expr
      bp = CheckBreakpoint.new(expr)
      add_bp bp
    end

    def add_line_breakpoint file, line, **kw
      file = resolve_path(file)
      bp = LineBreakpoint.new(file, line, **kw)

      add_bp bp
    rescue Errno::ENOENT => e
      @ui.puts e.message
    end

    # threads

    def update_thread_list
      list = Thread.list
      thcs = []
      unmanaged = []

      list.each{|th|
        if thc = @th_clients[th]
          if !thc.management?
            thcs << thc
          end
        else
          unmanaged << th
        end
      }

      return thcs.sort_by{|thc| thc.id}, unmanaged
    end

    def thread_list
      thcs, unmanaged_ths = update_thread_list
      thcs.each_with_index{|thc, i|
        @ui.puts "#{@tc == thc ? "--> " : "    "}\##{i} #{thc}"
      }

      if !unmanaged_ths.empty?
        @ui.puts "The following threads are not managed yet by the debugger:"
        unmanaged_ths.each{|th|
          @ui.puts "     " + th.to_s
        }
      end
    end

    def managed_thread_clients
      thcs, _unmanaged_ths = update_thread_list
      thcs
    end

    def thread_switch n
      thcs, _unmanaged_ths = update_thread_list

      if tc = thcs[n]
        if tc.waiting?
          @tc = tc
        else
          @ui.puts "#{tc.thread} is not controllable yet."
        end
      end
      thread_list
    end

    def thread_client_create th
      @th_clients[th] = ThreadClient.new((@tc_id += 1), @q_evt, Queue.new, th)
    end

    def setup_threads
      @th_clients = {}

      Thread.list.each{|th|
        thread_client_create(th)
      }
    end

    def on_thread_begin th
      if @th_clients.has_key? th
        # OK
      else
        # TODO: NG?
        thread_client_create th
      end
    end

    def thread_client thr = Thread.current
      if @th_clients.has_key? thr
        @th_clients[thr]
      else
        @th_clients[thr] = thread_client_create(thr)
      end
    end

    private def thread_stopper
      @thread_stopper ||= TracePoint.new(:line) do
        # run on each thread
        tc = ThreadClient.current
        next if tc.management?
        next unless tc.running?
        next if tc == @tc

        tc.on_pause
      end
    end

    private def running_thread_clients_count
      @th_clients.count{|th, tc|
        next if tc.management?
        next unless tc.running?
        true
      }
    end

    private def waiting_thread_clients
      @th_clients.map{|th, tc|
        next if tc.management?
        next unless tc.waiting?
        tc
      }.compact
    end

    private def stop_all_threads
      return if running_thread_clients_count == 0

      stopper = thread_stopper
      stopper.enable unless stopper.enabled?
    end

    private def restart_all_threads
      stopper = thread_stopper
      stopper.disable if stopper.enabled?

      waiting_thread_clients.each{|tc|
        next if @tc == tc
        tc << :continue
      }
      @tc = nil
    end

    ## event

    def on_load iseq, src
      DEBUGGER__.info "Load #{iseq.absolute_path || iseq.path}"
      @sr.add iseq, src

      pending_line_breakpoints = @bps.find_all do |key, bp|
        LineBreakpoint === bp && !bp.iseq
      end

      pending_line_breakpoints.each do |_key, bp|
        if bp.path == (iseq.absolute_path || iseq.path)
          bp.try_activate
        end
      end
    end

    def resolve_path file
      File.realpath(File.expand_path(file))
    rescue Errno::ENOENT
      case file
      when '-e', '-'
        return file
      else
        $LOAD_PATH.each do |lp|
          libpath = File.join(lp, file)
          return File.realpath(libpath)
        rescue Errno::ENOENT
          # next
        end
      end

      raise
    end

    def method_added tp
      b = tp.binding
      if var_name = b.local_variables.first
        mid = b.local_variable_get(var_name)
        unresolved = false

        @bps.each{|k, bp|
          case bp
          when MethodBreakpoint
            if bp.method.nil?
              if bp.sig_method_name == mid.to_s
                bp.try_enable(added: true)
              end
            end

            unresolved = true unless bp.enabled?
          end
        }
        unless unresolved
          METHOD_ADDED_TRACKER.disable
        end
      end
    end

    def width
      @ui.width
    end

    def check_postmortem
      if @postmortem
        raise PostmortemError, "Can not use this command on postmortem mode."
      end
    end

    def enter_postmortem_session frames
      @postmortem = true
      ThreadClient.current.suspend :postmortem, postmortem_frames: frames
    ensure
      @postmortem = false
    end

    def postmortem=(is_enable)
      if is_enable
        unless @postmortem_hook
          @postmortem_hook = TracePoint.new(:raise){|tp|
            exc = tp.raised_exception
            frames = DEBUGGER__.capture_frames(__dir__)
            exc.instance_variable_set(:@postmortem_frames, frames)
          }
          at_exit{
            @postmortem_hook.disable
            if CONFIG[:postmortem] && (exc = $!) != nil
              exc = exc.cause while exc.cause

              begin
                @ui.puts "Enter postmortem mode with #{exc.inspect}"
                @ui.puts exc.backtrace.map{|e| '  ' + e}
                @ui.puts "\n"

                enter_postmortem_session exc.instance_variable_get(:@postmortem_frames)
              rescue SystemExit
                exit!
              rescue Exception => e
                @ui = STDERR unless @ui
                @ui.puts "Error while postmortem console: #{e.inspect}"
              end
            end
          }
        end

        if !@postmortem_hook.enabled?
          @postmortem_hook.enable
        end
      else
        if @postmortem_hook && @postmortem_hook.enabled?
          @postmortem_hook.disable
        end
      end
    end

    def save_int_trap cmd
      prev, @intercepted_sigint_cmd = @intercepted_sigint_cmd, cmd
      prev
    end

    attr_reader :intercepted_sigint_cmd

    def intercept_trap_sigint?
      @intercept_trap_sigint
    end

    def intercept_trap_sigint flag, &b
      prev = @intercept_trap_sigint
      @intercept_trap_sigint = flag
      yield
    ensure
      @intercept_trap_sigint = prev
    end

    def intercept_trap_sigint_start prev
      @intercept_trap_sigint = true
      @intercepted_sigint_cmd = prev
    end
  end

  class UI_Base
    def event type, *args
      case type
      when :suspend_bp
        i, bp = *args
        puts "\nStop by \##{i} #{bp}" if bp
      when :suspend_trap
        sig = args.first
        puts "\nStop by #{args.first}"
      end
    end
  end

  # manual configuration methods

  def self.add_line_breakpoint file, line, **kw
    ::DEBUGGER__::SESSION.add_line_breakpoint file, line, **kw
  end

  def self.add_catch_breakpoint pat
    ::DEBUGGER__::SESSION.add_catch_breakpoint pat
  end

  # String for requring location
  # nil for -r
  def self.require_location
    locs = caller_locations
    dir_prefix = /#{__dir__}/

    locs.each do |loc|
      case loc.absolute_path
      when dir_prefix
      when %r{rubygems/core_ext/kernel_require\.rb}
      else
        return loc if loc.absolute_path
      end
    end
    nil
  end

  # start methods

  def self.start nonstop: false, **kw
    CONFIG.set_config(**kw)

    unless defined? SESSION
      require_relative 'local'
      initialize_session UI_LocalConsole.new
    end

    setup_initial_suspend unless nonstop
  end

  def self.open host: nil, port: CONFIG[:port], sock_path: nil, sock_dir: nil, nonstop: false, **kw
    CONFIG.set_config(**kw)

    if port
      open_tcp host: host, port: port, nonstop: nonstop
    else
      open_unix sock_path: sock_path, sock_dir: sock_dir, nonstop: nonstop
    end
  end

  def self.open_tcp host: nil, port:, nonstop: false, **kw
    CONFIG.set_config(**kw)
    require_relative 'server'

    if defined? SESSION
      SESSION.reset_ui UI_TcpServer.new(host: host, port: port)
    else
      initialize_session UI_TcpServer.new(host: host, port: port)
    end

    setup_initial_suspend unless nonstop
  end

  def self.open_unix sock_path: nil, sock_dir: nil, nonstop: false, **kw
    CONFIG.set_config(**kw)
    require_relative 'server'

    if defined? SESSION
      SESSION.reset_ui UI_UnixDomainServer.new(sock_dir: sock_dir, sock_path: sock_path)
    else
      initialize_session UI_UnixDomainServer.new(sock_dir: sock_dir, sock_path: sock_path)
    end

    setup_initial_suspend unless nonstop
  end

  # boot utilities

  def self.setup_initial_suspend
    if !CONFIG[:nonstop]
      case
      when path = ENV['RUBY_DEBUG_INITIAL_SUSPEND_PATH']
        add_line_breakpoint path, 0, oneshot: true, hook_call: false
      when loc = ::DEBUGGER__.require_location
        # require 'debug/start' or 'debug'
        add_line_breakpoint loc.absolute_path, loc.lineno + 1, oneshot: true, hook_call: false
      else
        # -r
        add_line_breakpoint $0, 0, oneshot: true, hook_call: false
      end
    end
  end

  class << self
    define_method :initialize_session do |ui|
      DEBUGGER__.info "Session start (pid: #{Process.pid})"
      ::DEBUGGER__.const_set(:SESSION, Session.new(ui))
      load_rc
    end
  end

  def self.load_rc
    [[File.expand_path('~/.rdbgrc'), true],
     [File.expand_path('~/.rdbgrc.rb'), true],
     # ['./.rdbgrc', true], # disable because of security concern
     [CONFIG[:init_script], false],
     ].each{|(path, rc)|
      next unless path
      next if rc && CONFIG[:no_rc] # ignore rc

      if File.file? path
        if path.end_with?('.rb')
          load path
        else
          ::DEBUGGER__::SESSION.add_preset_commands path, File.readlines(path)
        end
      elsif !rc
        warn "Not found: #{path}"
      end
    }

    # given debug commands
    if CONFIG[:commands]
      cmds = CONFIG[:commands].split(';;')
      ::DEBUGGER__::SESSION.add_preset_commands "commands", cmds, kick: false, continue: false
    end
  end

  class ::Module
    undef method_added
    def method_added mid; end
    def singleton_method_added mid; end
  end

  def self.method_added tp
    begin
      SESSION.method_added tp
    rescue Exception => e
      p e
    end
  end

  METHOD_ADDED_TRACKER = self.create_method_added_tracker

  SHORT_INSPECT_LENGTH = 40
  def self.short_inspect obj, use_short = true
    str = obj.inspect
    if use_short && str.length > SHORT_INSPECT_LENGTH
      str[0...SHORT_INSPECT_LENGTH] + '...'
    else
      str
    end
  end

  def self.warn msg
    log :WARN, msg
  end

  def self.info msg
    log :INFO, msg
  end

  def self.log level, msg
    lv = LOG_LEVELS[level]
    config_lv = LOG_LEVELS[CONFIG[:log_level] || :WARN]

    if lv <= config_lv
      if level == :WARN
        # :WARN on debugger is general information
        STDERR.puts "DEBUGGER: #{msg}"
      else
        STDERR.puts "DEBUGGER (#{level}): #{msg}"
      end
    end
  end

  module ForkInterceptor
    def fork(&given_block)
      return super unless defined?(SESSION) && SESSION.active?

      # before fork
      if CONFIG[:parent_on_fork]
        parent_hook = -> child_pid {
          # Do nothing
        }
        child_hook = -> {
          DEBUGGER__.warn "Detaching after fork from child process #{Process.pid}"
          SESSION.deactivate
        }
      else
        parent_pid = Process.pid

        parent_hook = -> child_pid {
          DEBUGGER__.warn "Detaching after fork from parent process #{Process.pid}"
          SESSION.deactivate

          at_exit{
            trap(:SIGINT, :IGNORE)

            # only check child process from its parent
            if Process.pid == parent_pid
              begin
                # sending a null signal to see if the child is still alive
                Process.kill(0, child_pid)
                # if the child is still alive, wait for it
                Process.waitpid(child_pid)
              rescue Errno::ESRCH
                # if the child process has died, do nothing
              end
            end
          }
        }
        child_hook = -> {
          DEBUGGER__.warn "Attaching after process #{parent_pid} fork to child process #{Process.pid}"
          SESSION.activate on_fork: true
        }
      end

      if given_block
        new_block = proc {
          # after fork: child
          child_hook.call
          given_block.call
        }
        pid = super(&new_block)
        parent_hook.call(pid)
        pid
      else
        if pid = super
          # after fork: parent
          parent_hook.call pid
        else
          # after fork: child
          child_hook.call
        end

        pid
      end
    end
  end

  class ::Object
    include ForkInterceptor
  end

  module ::Process
    class << self
      prepend ForkInterceptor
    end
  end

  module TrapInterceptor
    def trap sig, *command, &command_proc
      case sig&.to_sym
      when :INT, :SIGINT
        if defined?(SESSION) && SESSION.active? && SESSION.intercept_trap_sigint?
          return SESSION.save_int_trap(command.empty? ? command_proc : command.first)
        end
      end

      super
    end

    class ::Object
      include TrapInterceptor
    end

    module ::Signal
      class << self
        prepend TrapInterceptor
      end
    end
  end
end

module Kernel
  def debugger pre: nil, do: nil
    return if !defined?(::DEBUGGER__::SESSION) || !::DEBUGGER__::SESSION.active?

    if pre || (do_expr = binding.local_variable_get(:do))
      cmds = ['binding.break', pre, do_expr]
    end

    ::DEBUGGER__.add_line_breakpoint __FILE__, __LINE__ + 1, oneshot: true, command: cmds
    self
  end
end

class Binding
  alias break debugger
  alias b debugger
end



require_relative 'thread_client'
require_relative 'source_repository'
require_relative 'breakpoint'
require_relative 'config'

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
  class Session
    def initialize ui
      @ui = ui
      @sr = SourceRepository.new
      @bps = {} # bp.key => bp
                #   [file, line] => LineBreakpoint
                #   "Error" => CatchBreakpoint
                #   "Foo#bar" => MethodBreakpoint
                #   [:watch, expr] => WatchExprBreakpoint
                #   [:check, expr] => CheckBreakpoint
      @th_clients = {} # {Thread => ThreadClient}
      @q_evt = Queue.new
      @displays = []
      @tc = nil
      @tc_id = 0
      @initial_commands = []

      @tp_load_script = TracePoint.new(:script_compiled){|tp|
        ThreadClient.current.on_load tp.instruction_sequence, tp.eval_script
      }
      @tp_load_script.enable

      @session_server = Thread.new do
        Thread.current.abort_on_exception = true

        while evt = @q_evt.pop
          tc, output, ev, *ev_args = evt
          output.each{|str| @ui.puts str}

          case ev
          when :load
            iseq, src = ev_args
            on_load iseq, src
            tc << :continue
          when :thread_begin
            th = ev_args.shift
            on_thread_begin th
            tc << :continue
          when :suspend
            case ev_args.first
            when :breakpoint
              bp, i = bp_index ev_args[1]
              if bp
                @ui.puts "\nStop by \##{i} #{bp}"
              end
            when :trap
              @ui.puts ''
              @ui.puts "\nStop by #{ev_args[1]}"
            end

            if @displays.empty?
              wait_command_loop tc
            else
              tc << [:eval, :display, @displays]
            end
          when :result
            case ev_args.first
            when :watch
              bp = ev_args[1]
              @bps[bp.key] = bp
              show_bps bp
            when :try_display
              failed_results = ev_args[1]
              if failed_results.size > 0
                i, msg = failed_results.last
                if i+1 == @displays.size
                  @ui.puts "canceled: #{@displays.pop}"
                end
              end
            when :method_breakpoint
              bp = ev_args[1]
              if bp
                @bps[bp.key] = bp
                show_bps bp
              else
                # can't make a bp
              end
            else
              # ignore
            end

            wait_command_loop tc
          end
        end
      ensure
        @bps.each{|k, bp| bp.disable}
        @th_clients.each{|th, thc| thc.close}
      end

      @management_threads = [@session_server]
      @management_threads << @ui.reader_thread if @ui.respond_to? :reader_thread

      setup_threads

      @tp_thread_begin = TracePoint.new(:thread_begin){|tp|
        ThreadClient.current.on_thread_begin Thread.current
      }
      @tp_thread_begin.enable
    end

    def add_initial_commands cmds
      cmds.each{|c|
        c.gsub('#.*', '').strip!
        @initial_commands << c unless c.empty?
      }
    end

    def source iseq
      if CONFIG[:use_colorize]
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
      stop_all_threads do
        loop do
          case wait_command
          when :retry
            # nothing
          else
            break
          end
        rescue Interrupt
          retry
        end
      end
    ensure
      @tc = nil
    end

    def wait_command
      if @initial_commands.empty?
        line = @ui.readline
      else
        line = @initial_commands.shift.strip
        @ui.puts "(rdbg:init) #{line}"
      end

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
      when 's', 'step'
        @tc << [:step, :in]

      # * `n[ext]`
      #   * Step over. Resume the program until next line.
      when 'n', 'next'
        @tc << [:step, :next]

      # * `fin[ish]`
      #   * Finish this frame. Resume the program until the current frame is finished.
      when 'fin', 'finish'
        @tc << [:step, :finish]

      # * `c[ontinue]`
      #   * Resume the program.
      when 'c', 'continue'
        @tc << :continue

      # * `q[uit]` or `Ctrl-D`
      #   * Finish debugger (with the debuggee process on non-remote debugging).
      when 'q', 'quit'
        if ask 'Really quit?'
          @ui.quit arg.to_i
          @tc << :continue
        else
          return :retry
        end

      # * `q[uit]!`
      #   * Same as q[uit] but without the confirmation prompt.
      when 'q!', 'quit!'
        @ui.quit arg.to_i
        @tc << :continue

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
      # * `b[reak] ... if <expr>`
      #   * break if `<expr>` is true at specified location.
      # * `b[reak] if <expr>`
      #   * break if `<expr>` is true at any lines.
      #   * Note that this feature is super slow.
      when 'b', 'break'
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
        if arg
          bp = add_catch_breakpoint arg
          show_bps bp if bp
        else
          show_bps
        end
        return :retry

      # * `watch <expr>`
      #   * Stop the execution when the result of `<expr>` is changed.
      #   * Note that this feature is super slow.
      when 'wat', 'watch'
        if arg
          @tc << [:eval, :watch, arg]
        else
          show_bps
          return :retry
        end

      # * `del[ete]`
      #   * delete all breakpoints.
      # * `del[ete] <bpnum>`
      #   * delete specified breakpoint.
      when 'del', 'delete'
        bp =
        case arg
        when nil
          show_bps
          if ask "Remove all breakpoints?", 'N'
            delete_breakpoint
          end
        when /\d+/
          delete_breakpoint arg.to_i
        else
          nil
        end
        @ui.puts "deleted: \##{bp[0]} #{bp[1]}" if bp
        return :retry

      ### Information

      # * `bt` or `backtrace`
      #   * Show backtrace (frame) information.
      when 'bt', 'backtrace'
        @tc << [:show, :backtrace]

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

      # * `i[nfo]`, `i[nfo] l[ocal[s]]`
      #   * Show information about the current frame (local variables)
      #   * It includes `self` as `%self` and a return value as `%return`.
      # * `i[nfo] th[read[s]]
      #   * Show all threads (same as `th[read]`).
      when 'i', 'info'
        case arg
        when nil
          @tc << [:show, :local]
        when 'l', /locals?/
          @tc << [:show, :local]
        when 'th', /threads?/
          thread_list
          return :retry
        else
          show_help 'info'
          return :retry
        end

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
            if ask "clear \##{n} #{@displays[n]}?"
              @displays.delete_at n
            end
          end
          @tc << [:eval, :display, @displays]
        when nil
          if ask "clear all?", 'N'
            @displays.clear
          end
        end
        return :retry

      # * `trace [on|off]`
      #   * enable or disable line tracer.
      when 'trace'
        case arg
        when 'on'
          dir = __dir__
          @tracer ||= TracePoint.new(){|tp|
            next if File.dirname(tp.path) == dir
            next if tp.path == '<internal:trace_point>'
            # next if tp.event != :line
            @ui.puts pretty_tp(tp)
          }
          @tracer.enable
        when 'off'
          @tracer && @tracer.disable
        end
        enabled = (@tracer && @tracer.enabled?) ? true : false
        @ui.puts "Trace #{enabled ? 'on' : 'off'}"
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

      # * `e[val] <expr>`
      #   * Evaluate `<expr>` on the current frame.
      when 'e', 'eval', 'call'
        @tc << [:eval, :call, arg]

      # * `irb`
      #   * Invoke `irb` on the current frame.
      when 'irb'
        if @ui.remote?
          @ui.puts "not supported on the remote console."
          return :retry
        end
        @tc << [:eval, :call, 'binding.irb']

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

      ### Help

      # * `h[elp]`
      #   * Show help for all commands.
      # * `h[elp] <command>`
      #   * Show help for the given command.
      when 'h', 'help'
        if arg
          show_help arg
        else
          @ui.puts DEBUGGER__.help
        end
        return :retry

      ### END
      else
        @ui.puts "unknown command: #{line}"
        @repl_prev_line = nil
        return :retry
      end

    rescue Interrupt
      return :retry
    rescue SystemExit
      raise
    rescue Exception => e
      @ui.puts "[REPL ERROR] #{e.inspect}"
      @ui.puts e.backtrace.map{|e| '  ' + e}
      return :retry
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

    def msig klass, receiver
      if klass.singleton_class?
        "#{receiver}."
      else
        "#{klass}#"
      end
    end

    def pretty_tp tp
      loc = "#{tp.path}:#{tp.lineno}"
      level = caller.size

      info =
      case tp.event
      when :line
        "line at #{loc}"
      when :call, :c_call
        klass = tp.defined_class
        "#{tp.event} #{msig(klass, tp.self)}#{tp.method_id} at #{loc}"
      when :return, :c_return
        klass = tp.defined_class
        "#{tp.event} #{msig(klass, tp.self)}#{tp.method_id} => #{tp.return_value.inspect} at #{loc}"
      when :b_call
        "b_call at #{loc}"
      when :b_return
        "b_return => #{tp.return_value} at #{loc}"
      when :class
        "class #{tp.self} at #{loc}"
      when :end
        "class #{tp.self} end at #{loc}"
      else
        "#{tp.event} at #{loc}"
      end

      case tp.event
      when :call, :b_call, :return, :b_return, :class, :end
        level -= 1
      end

      "Tracing:#{' ' * level} #{info}"
    rescue => e
      p e
      pp e.backtrace
      exit!
    end

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

    def delete_breakpoint arg = nil
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

    def repl_add_breakpoint arg
      arg.strip!

      case arg
      when /\Aif\s+(.+)\z/
        cond = $1
      when /(.+?)\s+if\s+(.+)\z/
        sig = $1
        cond = $2
      else
        sig = arg
      end

      case sig
      when /\A(\d+)\z/
        add_line_breakpoint @tc.location.path, $1.to_i, cond: cond
      when /\A(.+)[:\s+](\d+)\z/
        add_line_breakpoint $1, $2.to_i, cond: cond
      when /\A(.+)([\.\#])(.+)\z/
        @tc << [:breakpoint, :method, $1, $2, $3, cond]
        return :noretry
      when nil
        add_check_breakpoint cond
      else
        @ui.puts "Unknown breakpoint format: #{arg}"
        @ui.puts
        show_help 'b'
      end
    end

    # threads

    def update_thread_list
      list = Thread.list
      thcs = []
      unmanaged = []

      list.each{|th|
        case
        when th == Thread.current
          # ignore
        when @th_clients.has_key?(th)
          thcs << @th_clients[th]
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

    def thread_switch n
      thcs, unmanaged_ths = update_thread_list

      if tc = thcs[n]
        if tc.mode
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
      stop_all_threads do
        Thread.list.each{|th|
          thread_client_create(th)
        }
      end
    end

    def on_thread_begin th
      if @th_clients.has_key? th
        # OK
      else
        # TODO: NG?
        thread_client_create th
      end
    end

    def thread_client
      thr = Thread.current
      if @th_clients.has_key? thr
        @th_clients[thr]
      else
        @th_clients[thr] = thread_client_create(thr)
      end
    end

    def stop_all_threads
      current = Thread.current

      if Thread.list.size > 1
        TracePoint.new(:line) do
          th = Thread.current
          if current == th || @management_threads.include?(th)
            next
          else
            tc = ThreadClient.current
            tc.on_pause
          end
        end.enable do
          yield
        ensure
          @th_clients.each{|thr, tc|
            case thr
            when current, (@tc && @tc.thread)
              next
            else
              tc << :continue if thr != Thread.current
            end
          }
        end
      else
        yield
      end
    end

    ## event

    def on_load iseq, src
      @sr.add iseq, src

      pending_line_breakpoints do |bp|
        if bp.path == (iseq.absolute_path || iseq.path)
          bp.try_activate
        end
      end
    end

    # breakpoint management

    def add_breakpoint bp
      if @bps.has_key? bp.key
        @ui.puts "duplicated breakpoint: #{bp}"
      else
        @bps[bp.key] = bp
      end
    end

    def rehash_bps
      bps = @bps.values
      @bps.clear
      bps.each{|bp|
        add_breakpoint bp
      }
    end

    def break? file, line
      @bps.has_key? [file, line]
    end

    def add_catch_breakpoint arg
      bp = CatchBreakpoint.new(arg)
      add_breakpoint bp
    end

    def add_check_breakpoint expr
      bp = CheckBreakpoint.new(expr)
      add_breakpoint bp
    end

    def resolve_path file
      File.realpath(File.expand_path(file))
    rescue Errno::ENOENT
      return file if file == '-e'
      $LOAD_PATH.each do |lp|
        libpath = File.join(lp, file)
        return File.realpath(libpath)
      rescue Errno::ENOENT
        # next
      end

      raise
    end

    def add_line_breakpoint file, line, **kw
      file = resolve_path(file)
      bp = LineBreakpoint.new(file, line, **kw)
      add_breakpoint bp
    rescue Errno::ENOENT => e
      @ui.puts e.message
    end

    def pending_line_breakpoints
      @bps.find_all do |key, bp|
        LineBreakpoint === bp && !bp.iseq
      end.each do |key, bp|
        yield bp
      end
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
                bp.try_enable(quiet: true)
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
        return loc
      end
    end
    nil
  end

  # start methods

  def self.console **kw
    set_config(kw)

    require_relative 'console'
    initialize_session UI_Console.new

    @prev_handler = trap(:SIGINT){
      ThreadClient.current.on_trap :SIGINT
    }
  end

  def self.open host: nil, port: ::DEBUGGER__::CONFIG[:port], sock_path: nil, sock_dir: nil, **kw
    set_config(kw)

    if port
      open_tcp host: host, port: port
    else
      open_unix sock_path: sock_path, sock_dir: sock_dir
    end
  end

  def self.open_tcp host: nil, port:, **kw
    set_config(kw)
    require_relative 'server'
    initialize_session UI_TcpServer.new(host: host, port: port)
  end

  def self.open_unix sock_path: nil, sock_dir: nil, **kw
    set_config(kw)
    require_relative 'server'
    initialize_session UI_UnixDomainServer.new(sock_dir: sock_dir, sock_path: sock_path)
  end

  # boot utilities

  class << self
    define_method :initialize_session do |ui|
      ::DEBUGGER__.const_set(:SESSION, Session.new(ui))

      # default breakpoints

      # ::DEBUGGER__.add_catch_breakpoint 'RuntimeError'

      Binding.module_eval do
        def bp command: nil
          if command
            cmds = commands.split(";;")
            SESSION.add_initial_commands cmds
          end

          ::DEBUGGER__.add_line_breakpoint __FILE__, __LINE__ + 1, oneshot: true
          true
        end
      end

      if !::DEBUGGER__::CONFIG[:nonstop]
        if loc = ::DEBUGGER__.require_location
          # require 'debug/console' or 'debug'
          add_line_breakpoint loc.absolute_path, loc.lineno + 1, oneshot: true, hook_call: false
        else
          # -r
          add_line_breakpoint $0, 1, oneshot: true, hook_call: false
        end
      end

      load_rc
    end
  end

  def self.load_rc
    ['./rdbgrc.rb', File.expand_path('~/.rdbgrc.rb')].each{|path|
      if File.file? path
        load path
      end
    }

    # debug commands file
    [init_script = ::DEBUGGER__::CONFIG[:init_script],
     './.rdbgrc',
     File.expand_path('~/.rdbgrc')].each{|path|
      next unless path

      if File.file? path
        ::DEBUGGER__::SESSION.add_initial_commands File.readlines(path)
      elsif path == init_script
        warn "Not found: #{path}"
      end
    }

    # given debug commands
    if ::DEBUGGER__::CONFIG[:commands]
      cmds = ::DEBUGGER__::CONFIG[:commands].split(';;')
      ::DEBUGGER__::SESSION.add_initial_commands cmds
    end
  end

  def self.parse_help
    helps = Hash.new{|h, k| h[k] = []}
    desc = cat = nil
    cmds = []

    File.read(__FILE__).each_line do |line|
      case line
      when /\A\s*### (.+)/
        cat = $1
        break if $1 == 'END'
      when /\A      when (.+)/
        next unless cat
        next unless desc
        ws = $1.split(/,\s*/).map{|e| e.gsub('\'', '')}
        helps[cat] << [ws, desc]
        desc = nil
        cmds.concat ws
      when /\A\s+# (\s*\*.+)/
        if desc
          desc << "\n" + $1
        else
          desc = $1
        end
      end
    end
    @commands = cmds
    @helps = helps
  end

  def self.helps
    (defined?(@helps) && @helps) || parse_help
  end

  def self.commands
    (defined?(@commands) && @commands) || (parse_help; @commands)
  end

  def self.help
    r = []
    self.helps.each{|cat, cmds|
      r << "### #{cat}"
      r << ''
      cmds.each{|ws, desc|
        r << desc
      }
      r << ''
    }
    r.join("\n")
  end

  class ::Module
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
end

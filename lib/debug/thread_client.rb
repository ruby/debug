# frozen_string_literal: true

require 'objspace'
require 'pp'

require_relative 'color'

module DEBUGGER__
  M_INSTANCE_VARIABLES = method(:instance_variables).unbind
  M_INSTANCE_VARIABLE_GET = method(:instance_variable_get).unbind
  M_CLASS = method(:class).unbind
  M_SINGLETON_CLASS = method(:singleton_class).unbind
  M_KIND_OF_P = method(:kind_of?).unbind
  M_RESPOND_TO_P = method(:respond_to?).unbind
  M_METHOD = method(:method).unbind
  M_OBJECT_ID = method(:object_id).unbind

  module SkipPathHelper
    def skip_path?(path)
      !path ||
      CONFIG.skip? ||
      ThreadClient.current.management? ||
      skip_internal_path?(path) ||
      skip_config_skip_path?(path)
    end

    def skip_config_skip_path?(path)
      (skip_paths = CONFIG[:skip_path]) && skip_paths.any?{|skip_path| path.match?(skip_path)}
    end

    def skip_internal_path?(path)
      path.start_with?(__dir__) || path.start_with?('<internal:')
    end

    def skip_location?(loc)
      loc_path = loc.absolute_path || "!eval:#{loc.path}"
      skip_path?(loc_path)
    end
  end

  class ThreadClient
    def self.current
      if thc = Thread.current[:DEBUGGER__ThreadClient]
        thc
      else
        thc = SESSION.get_thread_client
        Thread.current[:DEBUGGER__ThreadClient] = thc
      end
    end

    include Color
    include SkipPathHelper

    attr_reader :thread, :id, :recorder, :check_bp_fulfillment_map

    def location
      current_frame&.location
    end

    def assemble_arguments(args)
      args.map do |arg|
        "#{colorize_cyan(arg[:name])}=#{arg[:value]}"
      end.join(", ")
    end

    def default_frame_formatter frame
      call_identifier_str =
        case frame.frame_type
        when :block
          level, block_loc = frame.block_identifier
          args = frame.parameters_info

          if !args.empty?
            args_str = " {|#{assemble_arguments(args)}|}"
          end

          "#{colorize_blue("block")}#{args_str} in #{colorize_blue(block_loc + level)}"
        when :method
          ci = frame.method_identifier
          args = frame.parameters_info

          if !args.empty?
            args_str = "(#{assemble_arguments(args)})"
          end

          "#{colorize_blue(ci)}#{args_str}"
        when :c
          colorize_blue(frame.c_identifier)
        when :other
          colorize_blue(frame.other_identifier)
        end

      location_str = colorize(frame.location_str, [:GREEN])
      result = "#{call_identifier_str} at #{location_str}"

      if return_str = frame.return_str
        result += " #=> #{colorize_magenta(return_str)}"
      end

      result
    end

    def initialize id, q_evt, q_cmd, thr = Thread.current
      @is_management = false
      @id = id
      @thread = thr
      @target_frames = nil
      @q_evt = q_evt
      @q_cmd = q_cmd
      @step_tp = nil
      @output = []
      @frame_formatter = method(:default_frame_formatter)
      @var_map = {} # { thread_local_var_id => obj } for DAP
      @obj_map = {} # { object_id => obj } for CDP
      @recorder = nil
      @mode = :waiting
      @current_frame_index = 0
      # every thread should maintain its own CheckBreakpoint fulfillment state
      @check_bp_fulfillment_map = {} # { check_bp => boolean }
      set_mode :running
      thr.instance_variable_set(:@__thread_client_id, id)

      ::DEBUGGER__.info("Thread \##{@id} is created.")
    end

    def deactivate
      @step_tp.disable if @step_tp
    end

    def management?
      @is_management
    end

    def mark_as_management
      @is_management = true
    end

    def set_mode mode
      debug_mode(@mode, mode)
      # STDERR.puts "#{@mode} => #{mode} @ #{caller.inspect}"
      # pp caller

      # mode transition check
      case mode
      when :running
        raise "#{mode} is given, but #{mode}" unless self.waiting?
      when :waiting
        # TODO: there is waiting -> waiting
        # raise "#{mode} is given, but #{mode}" unless self.running?
      else
        raise "unknown mode: #{mode}"
      end

      # DEBUGGER__.warn "#{@mode} => #{mode} @ #{self.inspect}"
      @mode = mode
    end

    def running?
      @mode == :running
    end

    def waiting?
      @mode == :waiting
    end

    def name
      "##{@id} #{@thread.name || @thread.backtrace.last}"
    end

    def close
      @q_cmd.close
    end

    def inspect
      if bt = @thread.backtrace
        "#<DBG:TC #{self.id}:#{@mode}@#{bt[-1]}>"
      else # bt can be nil
        "#<DBG:TC #{self.id}:#{@mode}>"
      end
    end

    def to_s
      str = "(#{@thread.name || @thread.status})@#{current_frame&.location || @thread.to_s}"
      str += " (not under control)" unless self.waiting?
      str
    end

    def puts str = ''
      if @recorder&.replaying?
        prefix = colorize_dim("[replay] ")
      end
      case str
      when nil
        @output << "\n"
      when Array
        str.each{|s| puts s}
      else
        @output << "#{prefix}#{str.chomp}\n"
      end
    end

    def << req
      debug_cmd(req)
      @q_cmd << req
    end

    def generate_info
      return unless current_frame

      { location: current_frame.location_str, line: current_frame.location.lineno }
    end

    def event! ev, *args
      debug_event(ev, args)
      @q_evt << [self, @output, ev, generate_info, *args]
      @output = []
    end

    ## events

    def wait_reply event_arg
      return if management?

      set_mode :waiting

      event!(*event_arg)
      wait_next_action
    end

    def on_load iseq, eval_src
      wait_reply [:load, iseq, eval_src]
    end

    def on_init name
      wait_reply [:init, name]
    end

    def on_trace trace_id, msg
      wait_reply [:trace, trace_id, msg]
    end

    def on_breakpoint tp, bp
      suspend tp.event, tp, bp: bp
    end

    def on_trap sig
      if waiting?
        # raise Interrupt
      else
        suspend :trap, sig: sig
      end
    end

    def on_pause
      suspend :pause
    end

    def suspend event, tp = nil, bp: nil, sig: nil, postmortem_frames: nil, replay_frames: nil, postmortem_exc: nil
      return if management?
      debug_suspend(event)

      @current_frame_index = 0

      case
      when postmortem_frames
        @target_frames = postmortem_frames
        @postmortem = true
      when replay_frames
        @target_frames = replay_frames
      else
        @target_frames = DEBUGGER__.capture_frames(__dir__)
      end

      cf = @target_frames.first
      if cf
        case event
        when :return, :b_return, :c_return
          cf.has_return_value = true
          cf.return_value = tp.return_value
        end

        if CatchBreakpoint === bp
          cf.has_raised_exception = true
          cf.raised_exception = bp.last_exc
        end

        if postmortem_exc
          cf.has_raised_exception = true
          cf.raised_exception = postmortem_exc
        end
      end

      if event != :pause
        show_src
        show_frames CONFIG[:show_frames]

        set_mode :waiting

        if bp
          event! :suspend, :breakpoint, bp.key
        elsif sig
          event! :suspend, :trap, sig
        else
          event! :suspend, event
        end
      else
        set_mode :waiting
      end

      wait_next_action
    end

    def replay_suspend
      # @recorder.current_position
      suspend :replay, replay_frames: @recorder.current_frame
    end

    ## control all

    begin
      TracePoint.new(:raise){}.enable(target_thread: Thread.current)
      SUPPORT_TARGET_THREAD = true
    rescue ArgumentError
      SUPPORT_TARGET_THREAD = false
    end

    def step_tp iter, events = [:line, :b_return, :return]
      @step_tp.disable if @step_tp

      thread = Thread.current

      if SUPPORT_TARGET_THREAD
        @step_tp = TracePoint.new(*events){|tp|
          next if SESSION.break_at? tp.path, tp.lineno
          next if !yield(tp.event)
          next if tp.path.start_with?(__dir__)
          next if tp.path.start_with?('<internal:trace_point>')
          next unless File.exist?(tp.path) if CONFIG[:skip_nosrc]
          loc = caller_locations(1, 1).first
          next if skip_location?(loc)
          next if iter && (iter -= 1) > 0

          tp.disable
          suspend tp.event, tp
        }
        @step_tp.enable(target_thread: thread)
      else
        @step_tp = TracePoint.new(*events){|tp|
          next if thread != Thread.current
          next if SESSION.break_at? tp.path, tp.lineno
          next if !yield(tp.event)
          next if tp.path.start_with?(__dir__)
          next if tp.path.start_with?('<internal:trace_point>')
          next unless File.exist?(tp.path) if CONFIG[:skip_nosrc]
          loc = caller_locations(1, 1).first
          next if skip_location?(loc)
          next if iter && (iter -= 1) > 0

          tp.disable
          suspend tp.event, tp
        }
        @step_tp.enable
      end
    end

    ## cmd helpers

    if TracePoint.respond_to? :allow_reentry
      def tp_allow_reentry
        TracePoint.allow_reentry do
          yield
        end
      rescue RuntimeError => e
        # on the postmortem mode, it is not stopped in TracePoint
        if e.message == 'No need to allow reentrance.'
          yield
        else
          raise
        end
      end
    else
      def tp_allow_reentry
        yield
      end
    end

    def frame_eval_core src, b
      saved_target_frames = @target_frames
      saved_current_frame_index = @current_frame_index

      if b
        f, _l = b.source_location

        tp_allow_reentry do
          b.eval(src, "(rdbg)/#{f}")
        end
      else
        frame_self = current_frame.self

        tp_allow_reentry do
          frame_self.instance_eval(src)
        end
      end
    ensure
      @target_frames = saved_target_frames
      @current_frame_index = saved_current_frame_index
    end

    SPECIAL_LOCAL_VARS = [
      [:raised_exception, "_raised"],
      [:return_value,     "_return"],
    ]

    def frame_eval src, re_raise: false
      @success_last_eval = false

      b = current_frame.eval_binding

      special_local_variables current_frame do |name, var|
        b.local_variable_set(name, var) if /\%/ !~ name
      end

      result = frame_eval_core(src, b)

      @success_last_eval = true
      result

    rescue SystemExit
      raise
    rescue Exception => e
      return yield(e) if block_given?

      puts "eval error: #{e}"

      e.backtrace_locations&.each do |loc|
        break if loc.path == __FILE__
        puts "  #{loc}"
      end
      raise if re_raise
    end

    def get_src(frame,
                max_lines:,
                start_line: nil,
                end_line: nil,
                dir: +1)
      if file_lines = frame.file_lines
        frame_line = frame.location.lineno - 1

        lines = file_lines.map.with_index do |e, i|
          cur = i == frame_line ? '=>' : '  '
          line = colorize_dim('%4d|' % (i+1))
          "#{cur}#{line} #{e}"
        end

        unless start_line
          if frame.show_line
            if dir > 0
              start_line = frame.show_line
            else
              end_line = frame.show_line - max_lines
              start_line = [end_line - max_lines, 0].max
            end
          else
            start_line = [frame_line - max_lines/2, 0].max
          end
        end

        unless end_line
          end_line = [start_line + max_lines, lines.size].min
        end

        if start_line != end_line && max_lines
          [start_line, end_line, lines]
        end
      else # no file lines
        nil
      end
    rescue Exception => e
      p e
      pp e.backtrace
      exit!
    end

    def show_src(frame_index: @current_frame_index, update_line: false, max_lines: CONFIG[:show_src_lines], **options)
      if frame = get_frame(frame_index)
        start_line, end_line, lines = *get_src(frame, max_lines: max_lines, **options)

        if start_line
          if update_line
            frame.show_line = end_line
          end

          puts "[#{start_line+1}, #{end_line}] in #{frame.pretty_path}" if !update_line && max_lines != 1
          puts lines[start_line...end_line]
        else
          puts "# No sourcefile available for #{frame.path}"
        end
      end
    end

    def current_frame
      get_frame(@current_frame_index)
    end

    def get_frame(index)
      if @target_frames
        @target_frames[index]
      else
        nil
      end
    end

    def collect_locals(frame)
      locals = []

      if s = frame&.self
        locals << ["%self", s]
      end
      special_local_variables frame do |name, val|
        locals << [name, val]
      end

      if vars = frame&.local_variables
        vars.each{|var, val|
          locals << [var, val]
        }
      end

      locals
    end

    ## cmd: show

    def special_local_variables frame
      SPECIAL_LOCAL_VARS.each do |mid, name|
        next unless frame&.send("has_#{mid}")
        name = name.sub('_', '%') if frame.eval_binding.local_variable_defined?(name)
        yield name, frame.send(mid)
      end
    end

    def show_locals pat
      collect_locals(current_frame).each do |var, val|
        puts_variable_info(var, val, pat)
      end
    end

    def show_ivars pat
      if s = current_frame&.self
        M_INSTANCE_VARIABLES.bind_call(s).sort.each{|iv|
          value = M_INSTANCE_VARIABLE_GET.bind_call(s, iv)
          puts_variable_info iv, value, pat
        }
      end
    end

    def show_consts pat, only_self: false
      if s = current_frame&.self
        cs = {}
        if M_KIND_OF_P.bind_call(s, Module)
          cs[s] = :self
        else
          s = M_CLASS.bind_call(s)
          cs[s] = :self unless only_self
        end

        unless only_self
          s.ancestors.each{|c| break if c == Object; cs[c] = :ancestors}
          if b = current_frame&.binding
            b.eval('Module.nesting').each{|c| cs[c] = :nesting unless cs.has_key? c}
          end
        end

        names = {}

        cs.each{|c, _|
          c.constants(false).sort.each{|name|
            next if names.has_key? name
            names[name] = nil
            value = c.const_get(name)
            puts_variable_info name, value, pat
          }
        }
      end
    end

    SKIP_GLOBAL_LIST = %i[$= $KCODE $-K $SAFE].freeze
    def show_globals pat
      global_variables.sort.each{|name|
        next if SKIP_GLOBAL_LIST.include? name

        value = eval(name.to_s)
        puts_variable_info name, value, pat
      }
    end

    def puts_variable_info label, obj, pat
      return if pat && pat !~ label

      begin
        inspected = DEBUGGER__.safe_inspect(obj)
      rescue Exception => e
        inspected = e.inspect
      end
      mono_info = "#{label} = #{inspected}"

      w = SESSION::width

      if mono_info.length >= w
        maximum_value_width = w - "#{label} = ".length
        valstr = truncate(inspected, width: maximum_value_width)
      else
        valstr = colored_inspect(obj, width: 2 ** 30)
        valstr = inspected if valstr.lines.size > 1
      end

      info = "#{colorize_cyan(label)} = #{valstr}"

      puts info
    end

    def truncate(string, width:)
      if string.start_with?("#<")
        string[0 .. (width-5)] + '...>'
      else
        string[0 .. (width-4)] + '...'
      end
    end

    ### cmd: show edit

    def show_by_editor path = nil
      unless path
        if current_frame
          path = current_frame.path
        else
          return # can't get path
        end
      end

      if File.exist?(path)
        if editor = (ENV['RUBY_DEBUG_EDITOR'] || ENV['EDITOR'])
          puts "command: #{editor}"
          puts "   path: #{path}"
          system(editor, path)
        else
          puts "can not find editor setting: ENV['RUBY_DEBUG_EDITOR'] or ENV['EDITOR']"
        end
      else
        puts "Can not find file: #{path}"
      end
    end

    ### cmd: show frames

    def show_frames max = nil, pattern = nil
      if @target_frames && (max ||= @target_frames.size) > 0
        frames = []
        @target_frames.each_with_index{|f, i|
          # we need to use FrameInfo#matchable_location because #location_str is for display
          # and it may change based on configs (e.g. use_short_path)
          next if pattern && !(f.name.match?(pattern) || f.matchable_location.match?(pattern))
          # avoid using skip_path? because we still want to display internal frames
          next if skip_config_skip_path?(f.matchable_location)

          frames << [i, f]
        }

        size = frames.size
        max.times{|i|
          break unless frames[i]
          index, frame = frames[i]
          puts frame_str(index, frame: frame)
        }
        puts "  # and #{size - max} frames (use `bt' command for all frames)" if max < size
      end
    end

    def show_frame i=0
      puts frame_str(i)
    end

    def frame_str(i, frame: @target_frames[i])
      cur_str = (@current_frame_index == i ? '=>' : '  ')
      prefix = "#{cur_str}##{i}"
      frame_string = @frame_formatter.call(frame)
      "#{prefix}\t#{frame_string}"
    end

    ### cmd: show outline

    def show_outline expr
      begin
        obj = frame_eval(expr, re_raise: true)
      rescue Exception
        # ignore
      else
        o = Output.new(@output)

        locals = current_frame&.local_variables

        klass = M_CLASS.bind_call(obj)
        klass = obj if Class == klass || Module == klass

        o.dump("constants", obj.constants) if M_RESPOND_TO_P.bind_call(obj, :constants)
        outline_method(o, klass, obj)
        o.dump("instance variables", M_INSTANCE_VARIABLES.bind_call(obj))
        o.dump("class variables", klass.class_variables)
        o.dump("locals", locals.keys) if locals
      end
    end

    def outline_method(o, klass, obj)
      begin
        singleton_class = M_SINGLETON_CLASS.bind_call(obj)
      rescue TypeError
        singleton_class = nil
      end

      maps = class_method_map((singleton_class || klass).ancestors)
      maps.each do |mod, methods|
        name = mod == singleton_class ? "#{klass}.methods" : "#{mod}#methods"
        o.dump(name, methods)
      end
    end

    def class_method_map(classes)
      dumped = Array.new
      classes.reject { |mod| mod >= Object }.map do |mod|
        methods = mod.public_instance_methods(false).select do |m|
          dumped.push(m) unless dumped.include?(m)
        end
        [mod, methods]
      end.reverse
    end

    ## cmd: breakpoint

    # TODO: support non-ASCII Constant name
    def constant_name? name
      case name
      when /\A::\b/
        constant_name? $~.post_match
      when /\A[A-Z]\w*/
        post = $~.post_match
        if post.empty?
          true
        else
          constant_name? post
        end
      else
        false
      end
    end

    def make_breakpoint args
      case args.first
      when :method
        klass_name, op, method_name, cond, cmd, path = args[1..]
        bp = MethodBreakpoint.new(current_frame.eval_binding, klass_name, op, method_name, cond: cond, command: cmd, path: path)
        begin
          bp.enable
        rescue NameError => e
          if bp.klass
            puts "Unknown method name: \"#{e.name}\""
          else
            # klass_name can not be evaluated
            if constant_name? klass_name
              puts "Unknown constant name: \"#{e.name}\""
            else
              # only Class name is allowed
              puts "Not a constant name: \"#{klass_name}\""
              bp = nil
            end
          end

          Session.activate_method_added_trackers if bp
        rescue Exception => e
          puts e.inspect
          bp = nil
        end

        bp
      when :watch
        ivar, object, result, cond, command, path = args[1..]
        WatchIVarBreakpoint.new(ivar, object, result, cond: cond, command: command, path: path)
      else
        raise "unknown breakpoint: #{args}"
      end
    end

    class SuspendReplay < Exception
    end

    def wait_next_action
      wait_next_action_
    rescue SuspendReplay
      replay_suspend
    end

    def wait_next_action_
      # assertions
      raise "@mode is #{@mode}" if !waiting?

      unless SESSION.active?
        pp caller
        set_mode :running
        return
      end

      while true
        begin
          set_mode :waiting if !waiting?
          cmds = @q_cmd.pop
          # pp [self, cmds: cmds]
          break unless cmds
        ensure
          set_mode :running
        end

        cmd, *args = *cmds

        case cmd
        when :continue
          break

        when :step
          step_type = args[0]
          iter = args[1]

          case step_type
          when :in
            if @recorder&.replaying?
              @recorder.step_forward
              raise SuspendReplay
            else
              step_tp iter do
                true
              end
              break
            end

          when :next
            frame = @target_frames.first
            path = frame.location.absolute_path || "!eval:#{frame.path}"
            line = frame.location.lineno

            if frame.iseq
              frame.iseq.traceable_lines_norec(lines = {})
              next_line = lines.keys.bsearch{|e| e > line}
              if !next_line && (last_line = frame.iseq.last_line) > line
                next_line = last_line
              end
            end

            depth = @target_frames.first.frame_depth

            skip_line = false
            step_tp iter do |event|
              next if event == :line && skip_line

              loc = caller_locations(2, 1).first
              loc_path = loc.absolute_path || "!eval:#{loc.path}"

              frame_depth = DEBUGGER__.frame_depth - 3

              # If we're at a deeper stack depth, we can skip line events until there's a return event.
              skip_line = event == :line && frame_depth > depth

              # same stack depth
              (frame_depth <= depth) ||

              # different frame
              (next_line && loc_path == path &&
               (loc_lineno = loc.lineno) > line &&
               loc_lineno <= next_line)
            end
            break

          when :finish
            finish_frames = (iter || 1) - 1
            goal_depth = @target_frames.first.frame_depth - finish_frames

            step_tp nil, [:return, :b_return] do
              DEBUGGER__.frame_depth - 3 <= goal_depth ? true : false
            end
            break

          when :back
            if @recorder&.can_step_back?
              unless @recorder.backup_frames
                @recorder.backup_frames = @target_frames
              end
              @recorder.step_back
              raise SuspendReplay
            else
              puts "Can not step back more."
              event! :result, nil
            end

          when :reset
            if @recorder&.replaying?
              @recorder.step_reset
              raise SuspendReplay
            end

          else
            raise "unknown: #{type}"
          end

        when :eval
          eval_type, eval_src = *args

          result_type = nil

          case eval_type
          when :p
            result = frame_eval(eval_src)
            puts "=> " + color_pp(result, 2 ** 30)
            if alloc_path = ObjectSpace.allocation_sourcefile(result)
              puts "allocated at #{alloc_path}:#{ObjectSpace.allocation_sourceline(result)}"
            end
          when :pp
            result = frame_eval(eval_src)
            puts color_pp(result, SESSION.width)
            if alloc_path = ObjectSpace.allocation_sourcefile(result)
              puts "allocated at #{alloc_path}:#{ObjectSpace.allocation_sourceline(result)}"
            end
          when :call
            result = frame_eval(eval_src)
          when :irb
            begin
              result = frame_eval('binding.irb')
            ensure
              # workaround: https://github.com/ruby/debug/issues/308
              Reline.prompt_proc = nil if defined? Reline
            end
          when :display, :try_display
            failed_results = []
            eval_src.each_with_index{|src, i|
              result = frame_eval(src){|e|
                failed_results << [i, e.message]
                "<error: #{e.message}>"
              }
              puts "#{i}: #{src} = #{result}"
            }

            result_type = eval_type
            result = failed_results
          else
            raise "unknown error option: #{args.inspect}"
          end

          event! :result, result_type, result
        when :frame
          type, arg = *args
          case type
          when :up
            if @current_frame_index + 1 < @target_frames.size
              @current_frame_index += 1
              show_src max_lines: 1
              show_frame(@current_frame_index)
            end
          when :down
            if @current_frame_index > 0
              @current_frame_index -= 1
              show_src max_lines: 1
              show_frame(@current_frame_index)
            end
          when :set
            if arg
              index = arg.to_i
              if index >= 0 && index < @target_frames.size
                @current_frame_index = index
              else
                puts "out of frame index: #{index}"
              end
            end
            show_src max_lines: 1
            show_frame(@current_frame_index)
          else
            raise "unsupported frame operation: #{arg.inspect}"
          end

          event! :result, nil

        when :show
          type = args.shift

          case type
          when :backtrace
            max_lines, pattern = *args
            show_frames max_lines, pattern

          when :list
            show_src(update_line: true, **(args.first || {}))

          when :edit
            show_by_editor(args.first)

          when :default
            pat = args.shift
            show_locals pat
            show_ivars  pat
            show_consts pat, only_self: true

          when :locals
            pat = args.shift
            show_locals pat

          when :ivars
            pat = args.shift
            show_ivars pat

          when :consts
            pat = args.shift
            show_consts pat

          when :globals
            pat = args.shift
            show_globals pat

          when :outline
            show_outline args.first || 'self'

          else
            raise "unknown show param: " + [type, *args].inspect
          end

          event! :result, nil

        when :breakpoint
          case args[0]
          when :method
            bp = make_breakpoint args
            event! :result, :method_breakpoint, bp
          when :watch
            ivar, cond, command, path = args[1..]
            result = frame_eval(ivar)

            if @success_last_eval
              object =
                if b = current_frame.binding
                  b.receiver
                else
                  current_frame.self
                end
              bp = make_breakpoint [:watch, ivar, object, result, cond, command, path]
              event! :result, :watch_breakpoint, bp
            else
              event! :result, nil
            end
          end

        when :trace
          case args.shift
          when :object
            begin
              obj = frame_eval args.shift, re_raise: true
              opt = args.shift
              obj_inspect = DEBUGGER__.safe_inspect(obj)

              width = 50

              if obj_inspect.length >= width
                obj_inspect = truncate(obj_inspect, width: width)
              end

              event! :result, :trace_pass, M_OBJECT_ID.bind_call(obj), obj_inspect, opt
            rescue => e
              puts e.message
              event! :result, nil
            end
          else
            raise "unreachable"
          end

        when :record
          case args[0]
          when nil
            # ok
          when :on
            # enable recording
            if !@recorder
              @recorder = Recorder.new
            end
            @recorder.enable
          when :off
            if @recorder&.enabled?
              @recorder.disable
            end
          else
            raise "unknown: #{args.inspect}"
          end

          if @recorder&.enabled?
            puts "Recorder for #{Thread.current}: on (#{@recorder.log.size} records)"
          else
            puts "Recorder for #{Thread.current}: off"
          end
          event! :result, nil

        when :dap
          process_dap args
        when :cdp
          process_cdp args
        else
          raise [cmd, *args].inspect
        end
      end

    rescue SuspendReplay, SystemExit, Interrupt
      raise
    rescue Exception => e
      pp ["DEBUGGER Exception: #{__FILE__}:#{__LINE__}", e, e.backtrace]
      raise
    end

    def debug_event(ev, args)
      DEBUGGER__.debug{
        args = args.map { |arg| DEBUGGER__.safe_inspect(arg) }
        "#{inspect} sends Event { type: #{ev.inspect}, args: #{args} } to Session"
      }
    end

    def debug_mode(old_mode, new_mode)
      DEBUGGER__.debug{
        "#{inspect} changes mode (#{old_mode} -> #{new_mode})"
      }
    end

    def debug_cmd(cmds)
      DEBUGGER__.debug{
        cmd, *args = *cmds
        args = args.map { |arg| DEBUGGER__.safe_inspect(arg) }
        "#{inspect} receives Cmd { type: #{cmd.inspect}, args: #{args} } from Session"
      }
    end

    def debug_suspend(event)
      DEBUGGER__.debug{
        "#{inspect} is suspended for #{event.inspect}"
      }
    end

    class Recorder
      attr_reader :log, :index
      attr_accessor :backup_frames

      include SkipPathHelper

      def initialize
        @log = []
        @index = 0
        @backup_frames = nil
        thread = Thread.current

        @tp_recorder ||= TracePoint.new(:line){|tp|
          next unless Thread.current == thread
          # can't be replaced by skip_location
          next if skip_internal_path?(tp.path)
          loc = caller_locations(1, 1).first
          next if skip_location?(loc)

          frames = DEBUGGER__.capture_frames(__dir__)
          frames.each{|frame|
            if b = frame.binding
              frame.binding = nil
              frame._local_variables = b.local_variables.map{|name|
                [name, b.local_variable_get(name)]
              }.to_h
              frame._callee = b.eval('__callee__')
            end
          }
          @log << frames
        }
      end

      def enable
        unless @tp_recorder.enabled?
          @log.clear
          @tp_recorder.enable
        end
      end

      def disable
        if @tp_recorder.enabled?
          @log.clear
          @tp_recorder.disable
        end
      end

      def enabled?
        @tp_recorder.enabled?
      end

      def step_back
        @index += 1
      end

      def step_forward
        @index -= 1
      end

      def step_reset
        @index = 0
        @backup_frames = nil
      end

      def replaying?
        @index > 0
      end

      def can_step_back?
        log.size > @index
      end

      def log_index
        @log.size - @index
      end

      def current_frame
        if @index == 0
          f = @backup_frames
          @backup_frames = nil
          f
        else
          frames = @log[log_index]
          frames
        end
      end

      # for debugging
      def current_position
        puts "INDEX: #{@index}"
        li = log_index
        @log.each_with_index{|frame, i|
          loc = frame.first&.location
          prefix = i == li ? "=> " : '   '
          puts "#{prefix} #{loc}"
        }
      end
    end

    # copied from irb
    class Output
      include Color

      MARGIN = "  "

      def initialize(output)
        @output = output
        @line_width = screen_width - MARGIN.length # right padding
      end

      def dump(name, strs)
        strs = strs.sort
        return if strs.empty?

        line = "#{colorize_blue(name)}: "

        # Attempt a single line
        if fits_on_line?(strs, cols: strs.size, offset: "#{name}: ".length)
          line += strs.join(MARGIN)
          @output << line
          return
        end

        # Multi-line
        @output << line

        # Dump with the largest # of columns that fits on a line
        cols = strs.size
        until fits_on_line?(strs, cols: cols, offset: MARGIN.length) || cols == 1
          cols -= 1
        end
        widths = col_widths(strs, cols: cols)
        strs.each_slice(cols) do |ss|
          @output << ss.map.with_index { |s, i| "#{MARGIN}%-#{widths[i]}s" % s }.join
        end
      end

      private

      def fits_on_line?(strs, cols:, offset: 0)
        width = col_widths(strs, cols: cols).sum + MARGIN.length * (cols - 1)
        width <= @line_width - offset
      end

      def col_widths(strs, cols:)
        cols.times.map do |col|
          (col...strs.size).step(cols).map do |i|
            strs[i].length
          end.max
        end
      end

      def screen_width
        SESSION.width
      rescue Errno::EINVAL # in `winsize': Invalid argument - <STDIN>
        80
      end
    end
    private_constant :Output
  end
end

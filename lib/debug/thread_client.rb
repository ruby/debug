# frozen_string_literal: true

require 'objspace'
require 'pp'

require_relative 'frame_info'
require_relative 'color'

module DEBUGGER__
  class ThreadClient
    def self.current
      Thread.current[:DEBUGGER__ThreadClient] || begin
        tc = ::DEBUGGER__::SESSION.thread_client
        Thread.current[:DEBUGGER__ThreadClient] = tc
      end
    end

    include Color

    attr_reader :location, :thread, :mode, :id

    def assemble_arguments(args)
      args.map do |arg|
        "#{colorize_cyan(arg[:name])}=#{arg[:value]}"
      end.join(", ")
    end

    def default_frame_formatter frame
      call_identifier_str =
        case frame.frame_type
        when :block
          level, block_loc, args = frame.block_identifier

          if !args.empty?
            args_str = " {|#{assemble_arguments(args)}|}"
          end

          "#{colorize_blue("block")}#{args_str} in #{colorize_blue(block_loc + level)}"
        when :method
          ci, args = frame.method_identifier

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
        return_str = colorize(frame.return_str, [:MAGENTA, :BOLD])
        result += " #=> #{return_str}"
      end

      result
    end

    def initialize id, q_evt, q_cmd, thr = Thread.current
      @id = id
      @thread = thr
      @target_frames = nil
      @q_evt = q_evt
      @q_cmd = q_cmd
      @step_tp = nil
      @output = []
      @frame_formatter = method(:default_frame_formatter)
      @var_map = {} # { thread_local_var_id => obj } for DAP
      set_mode nil
      thr.instance_variable_set(:@__thread_client_id, id)

      ::DEBUGGER__.info("Thread \##{@id} is created.")
    end

    def set_mode mode
      @mode = mode
    end

    def name
      "##{@id} #{@thread.name || @thread.backtrace.last}"
    end

    def close
      @q_cmd.close
    end

    def inspect
      "#<DBG:TC #{self.id}:#{self.mode}@#{@thread.backtrace[-1]}>"
    end

    def to_s
      loc = current_frame&.location

      if loc
        str = "(#{@thread.name || @thread.status})@#{loc}"
      else
        str = "(#{@thread.name || @thread.status})@#{@thread.to_s}"
      end

      str += " (not under control)" unless self.mode
      str
    end

    def puts str = ''
      case str
      when nil
        @output << "\n"
      when Array
        str.each{|s| puts s}
      else
        @output << str.chomp + "\n"
      end
    end

    def << req
      @q_cmd << req
    end

    def generate_info
      return unless current_frame

      { location: current_frame.location_str, line: current_frame.location.lineno }
    end

    def event! ev, *args
      @q_evt << [self, @output, ev, generate_info, *args]
      @output = []
    end

    ## events

    def on_trap sig
      if self.mode == :wait_next_action
        # raise Interrupt
      else
        on_suspend :trap, sig: sig
      end
    end

    def on_pause
      on_suspend :pause
    end

    def on_thread_begin th
      event! :thread_begin, th
      wait_next_action
    end

    def on_load iseq, eval_src
      event! :load, iseq, eval_src
      wait_next_action
    end

    def on_init name
      event! :init, name
      wait_next_action
    end

    def on_breakpoint tp, bp
      on_suspend tp.event, tp, bp: bp
    end

    def on_trace trace_id, msg
      event! :trace, trace_id, msg
      wait_next_action
    end

    def on_suspend event, tp = nil, bp: nil, sig: nil, postmortem_frames: nil
      @current_frame_index = 0

      if postmortem_frames
        @target_frames = postmortem_frames
        @postmortem = true
      else
        @target_frames = DEBUGGER__.capture_frames(__dir__)
      end

      cf = @target_frames.first
      if cf
        @location = cf.location
        case event
        when :return, :b_return, :c_return
          cf.has_return_value = true
          cf.return_value = tp.return_value
        end

        if CatchBreakpoint === bp
          cf.has_raised_exception = true
          cf.raised_exception = bp.last_exc
        end
      end

      if event != :pause
        show_src max_lines: (CONFIG[:show_src_lines] || 10)
        show_frames CONFIG[:show_frames] || 2

        if bp
          event! :suspend, :breakpoint, bp.key
        elsif sig
          event! :suspend, :trap, sig
        else
          event! :suspend, event
        end
      end

      wait_next_action
    end

    ## control all

    begin
      TracePoint.new(:raise){}.enable(target_thread: Thread.current)
      SUPPORT_TARGET_THREAD = true
    rescue ArgumentError
      SUPPORT_TARGET_THREAD = false
    end

    def step_tp
      @step_tp.disable if @step_tp

      thread = Thread.current

      if SUPPORT_TARGET_THREAD
        @step_tp = TracePoint.new(:line, :b_return, :return){|tp|
          next if SESSION.break? tp.path, tp.lineno
          next if !yield
          next if tp.path.start_with?(__dir__)
          next unless File.exist?(tp.path) if CONFIG[:skip_nosrc]
          loc = caller_locations(1, 1).first
          loc_path = loc.absolute_path || "!eval:#{loc.path}"
          next if skip_path?(loc_path)

          tp.disable
          on_suspend tp.event, tp
        }
        @step_tp.enable(target_thread: thread)
      else
        @step_tp = TracePoint.new(:line, :b_return, :return){|tp|
          next if thread != Thread.current
          next if SESSION.break? tp.path, tp.lineno
          next if !yield
          next unless File.exist?(tp.path) if CONFIG[:skip_nosrc]
          loc = caller_locations(1, 1).first
          loc_path = loc.absolute_path || "!eval:#{loc.path}"
          next if skip_path?(loc_path)

          tp.disable
          on_suspend tp.event, tp
        }
        @step_tp.enable
      end
    end

    def skip_path?(path)
      CONFIG[:skip_path] && CONFIG[:skip_path].any? { |skip_path| path.match?(skip_path) }
    end

    ## cmd helpers

    # this method is extracted to hide frame_eval's local variables from C method eval's binding
    def instance_eval_for_cmethod frame_self, src
      frame_self.instance_eval(src)
    end

    def frame_eval src, re_raise: false
      begin
        @success_last_eval = false

        b = current_frame.binding
        result = if b
                   f, _l = b.source_location
                   b.eval(src, "(rdbg)/#{f}")
                 else
                   frame_self = current_frame.self
                   instance_eval_for_cmethod(frame_self, src)
                 end
        @success_last_eval = true
        result

      rescue Exception => e
        return yield(e) if block_given?

        puts "eval error: #{e}"

        e.backtrace_locations.each do |loc|
          break if loc.path == __FILE__
          puts "  #{loc}"
        end
        raise if re_raise
      end
    end

    def show_src(frame_index: @current_frame_index,
                 update_line: false,
                 max_lines: 10,
                 start_line: nil,
                 end_line: nil,
                 dir: +1)
      if @target_frames && frame = @target_frames[frame_index]
        if file_lines = frame.file_lines
          frame_line = frame.location.lineno - 1

          lines = file_lines.map.with_index do |e, i|
            if i == frame_line
              "=> #{'%4d' % (i+1)}| #{e}"
            else
              "   #{'%4d' % (i+1)}| #{e}"
            end
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

          if update_line
            frame.show_line = end_line
          end

          if start_line != end_line && max_lines
            puts "[#{start_line+1}, #{end_line}] in #{frame.pretty_path}" if !update_line && max_lines != 1
            puts lines[start_line ... end_line]
          end
        else # no file lines
          puts "# No sourcefile available for #{frame.path}"
        end
      end
    rescue Exception => e
      p e
      pp e.backtrace
      exit!
    end

    def current_frame
      if @target_frames
        @target_frames[@current_frame_index]
      else
        nil
      end
    end

    ## cmd: show

    def show_locals pat
      if s = current_frame&.self
        puts_variable_info '%self', s, pat
      end
      if current_frame&.has_return_value
        puts_variable_info '%return', current_frame.return_value, pat
      end
      if current_frame&.has_raised_exception
        puts_variable_info "%raised", current_frame.raised_exception, pat
      end
      if b = current_frame&.binding
        b.local_variables.sort.each{|loc|
          value = b.local_variable_get(loc)
          puts_variable_info loc, value, pat
        }
      end
    end

    def show_ivars pat
      if s = current_frame&.self
        s.instance_variables.sort.each{|iv|
          value = s.instance_variable_get(iv)
          puts_variable_info iv, value, pat
        }
      end
    end

    def show_consts pat, only_self: false
      if s = current_frame&.self
        cs = {}
        if s.kind_of? Module
          cs[s] = :self
        else
          s = s.class
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
        inspected = obj.inspect
      rescue Exception => e
        inspected = e.inspect
      end
      mono_info = "#{label} = #{inspected}"

      w = SESSION::width

      if mono_info.length >= w
        info = mono_info[0 .. (w-4)] + '...'
      else
        valstr = colored_inspect(obj, width: 2 ** 30)
        valstr = inspected if valstr.lines.size > 1
        info = "#{colorize_cyan(label)} = #{valstr}"
      end

      puts info
    end

    ### cmd: show edit

    def show_by_editor path = nil
      unless path
        if @target_frames && frame = @target_frames[@current_frame_index]
          path = frame.path
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
          next if pattern && !(f.name.match?(pattern) || f.location_str.match?(pattern))
          next if CONFIG[:skip_path] && CONFIG[:skip_path].any?{|pat|
            case pat
            when String
              f.location_str.start_with?(pat)
            when Regexp
              f.location_str.match?(pat)
            end
          }

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

        locals = current_frame.binding.local_variables
        klass  = (obj.class == Class || obj.class == Module ? obj : obj.class)

        o.dump("constants", obj.constants) if obj.respond_to?(:constants)
        outline_method(o, klass, obj)
        o.dump("instance variables", obj.instance_variables)
        o.dump("class variables", klass.class_variables)
        o.dump("locals", locals)
      end
    end

    def outline_method(o, klass, obj)
      singleton_class = begin obj.singleton_class; rescue TypeError; nil end
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

    def make_breakpoint args
      case args.first
      when :method
        klass_name, op, method_name, cond, cmd = args[1..]
        bp = MethodBreakpoint.new(current_frame.binding, klass_name, op, method_name, cond, command: cmd)
        begin
          bp.enable
        rescue Exception => e
          puts e.message
          ::DEBUGGER__::METHOD_ADDED_TRACKER.enable
        end

        bp
      when :watch
        ivar, object, result = args[1..]
        WatchIVarBreakpoint.new(ivar, object, result)
      else
        raise "unknown breakpoint: #{args}"
      end
    end

    def wait_next_action
      set_mode :wait_next_action

      SESSION.check_forked

      while cmds = @q_cmd.pop
        # pp [self, cmds: cmds]

        cmd, *args = *cmds

        case cmd
        when :continue
          break
        when :step
          step_type = args[0]
          case step_type
          when :in
            step_tp{true}
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

            step_tp{
              loc = caller_locations(2, 1).first
              loc_path = loc.absolute_path || "!eval:#{loc.path}"

              # same stack depth
              (DEBUGGER__.frame_depth - 3 <= depth) ||

              # different frame
              (next_line && loc_path == path &&
               (loc_lineno = loc.lineno) > line &&
               loc_lineno <= next_line)
            }
          when :finish
            depth = @target_frames.first.frame_depth
            step_tp{
              # 3 is debugger's frame count
              DEBUGGER__.frame_depth - 3 < depth
            }
          else
            raise
          end
          break
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
            ivar = args[1]
            result = frame_eval(ivar)

            if @success_last_eval
              object =
                if b = current_frame.binding
                  b.receiver
                else
                  current_frame.self
                end
              bp = make_breakpoint [:watch, ivar, object, result]
              event! :result, :watch_breakpoint, bp
            else
              event! :result, nil
            end
          end

        when :trace
          case args.shift
          when :pass
            obj = frame_eval args.shift
            opt = args.shift
            event! :result, :trace_pass, obj.object_id, obj.inspect, opt
          else
            raise "unreachable"
          end
        when :dap
          process_dap args
        else
          raise [cmd, *args].inspect
        end
      end

    rescue SystemExit
      raise
    rescue Exception => e
      pp ["DEBUGGER Exception: #{__FILE__}:#{__LINE__}", e, e.backtrace]
      raise
    ensure
      set_mode nil
    end

    # copyed from irb
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

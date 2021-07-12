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

      ::DEBUGGER__.info("Thread \##{@id} is created.")
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

    def on_suspend event, tp = nil, bp: nil, sig: nil
      @current_frame_index = 0
      @target_frames = DEBUGGER__.capture_frames __dir__

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
        show_src max_lines: (::DEBUGGER__::CONFIG[:show_src_lines] || 10)
        show_frames ::DEBUGGER__::CONFIG[:show_frames] || 2

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
          next unless File.exist?(tp.path) if ::DEBUGGER__::CONFIG[:skip_nosrc]

          tp.disable
          on_suspend tp.event, tp
        }
        @step_tp.enable(target_thread: thread)
      else
        @step_tp = TracePoint.new(:line, :b_return, :return){|tp|
          next if thread != Thread.current
          next if SESSION.break? tp.path, tp.lineno
          next if !yield
          next unless File.exist?(tp.path) if ::DEBUGGER__::CONFIG[:skip_nosrc]

          tp.disable
          on_suspend tp.event, tp
        }
        @step_tp.enable
      end
    end

    def current_frame
      if @target_frames
        @target_frames[@current_frame_index]
      else
        nil
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

    def puts_variable_info label, obj
      info = "#{colorize_cyan(label)} => #{colored_inspect(obj)}".lines
      w = SESSION.width
      max_inspect_lines = CONFIG[:show_inspect_lines] || 10

      if (max_inspect_lines > 0 && (info.size > max_inspect_lines)) || info.any?{|l| l.size > w}
        info = "#{colorize_cyan(label)} => #{colored_inspect(obj, no_color: true)}".lines
        if max_inspect_lines > 0 && info.size > max_inspect_lines
          info = info.first(max_inspect_lines - 2) +
                 ["...(#{info.size - (max_inspect_lines - 1)} lines)\n" + info.last]
        end
        info.map!{|l|
          l.length > w ? l[0..(w-4)] + '...' : l
        }
      end

      puts info
    end

    def show_locals
      if s = current_frame&.self
        puts_variable_info '%self', s
      end
      if current_frame&.has_return_value
        puts_variable_info '%return', current_frame.return_value
      end
      if current_frame&.has_raised_exception
        puts_variable_info "%raised", current_frame.raised_exception
      end
      if b = current_frame&.binding
        b.local_variables.each{|loc|
          value = b.local_variable_get(loc)
          puts_variable_info loc, value
        }
      end
    end

    def show_ivars
      if s = current_frame&.self
        s.instance_variables.each{|iv|
          value = s.instance_variable_get(iv)
          puts_variable_info iv, value
        }
      end
    end

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

    def frame_str(i, frame: @target_frames[i])
      cur_str = (@current_frame_index == i ? '=>' : '  ')
      prefix = "#{cur_str}##{i}"
      frame_string = @frame_formatter.call(frame)
      "#{prefix}\t#{frame_string}"
    end

    def show_frames max = nil, pattern = nil
      if @target_frames && (max ||= @target_frames.size) > 0
        frames = []
        if pattern
          @target_frames.each_with_index{|f, i|
            frames << [i, f] if f.name.match?(pattern) || f.location_str.match?(pattern)
          }
        else
          frames = @target_frames.map.with_index{|f, i| [i, f]}
        end

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

    def show_object_info expr
      begin
        result = frame_eval(expr, re_raise: true)
      rescue Exception
        # ignore
      else
        klass = ObjectSpace.internal_class_of(result)
        exists = []
        klass.ancestors.each{|k|
          puts "= #{k}"
          if (ms = (k.instance_methods(false) - exists)).size > 0
            puts ms.sort.join("\t")
            exists |= ms
          end
        }
      end
    end

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

    def set_mode mode
      @mode = mode
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
            puts "=> " + result.inspect
          when :pp
            result = frame_eval(eval_src)
            puts "=> "
            puts color_pp(result, SESSION.width)
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

          when :local
            show_frame
            show_locals
            show_ivars

          when :object_info
            expr = args.shift
            show_object_info expr

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
  end
end

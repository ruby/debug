module DEBUGGER__
  class Breakpoint
    attr_reader :key

    def initialize do_enable = true
      @deleted = false

      setup
      enable if do_enable
    end

    def safe_eval b, expr
      b.eval(expr)
    rescue Exception => e
      puts "[EVAL ERROR]"
      puts "  expr: #{expr}"
      puts "  err: #{e} (#{e.class})"
      puts "Error caused by #{self}."
      nil
    end

    def setup
      raise "not implemented..."
    end

    def enable
      @tp.enable
    end

    def disable
      @tp&.disable
    end

    def enabled?
      @tp.enabled?
    end

    def delete
      disable
      @deleted = true
    end

    def deleted?
      @deleted
    end

    def suspend
      ThreadClient.current.on_breakpoint @tp, self
    end

    def to_s
      if @cond
        " if #{@cond}"
      else
        ""
      end
    end
  end

  class LineBreakpoint < Breakpoint
    attr_reader :path, :line, :iseq

    def initialize path, line, cond: nil, oneshot: false, hook_call: true
      @path = path
      @line = line
      @cond = cond
      @oneshot = oneshot
      @hook_call = hook_call

      @iseq = nil
      @type = nil

      @key = [@path, @line].freeze

      super()
      try_activate
    end

    def setup
      return unless @type

      if !@cond
        @tp = TracePoint.new(@type) do |tp|
          delete if @oneshot
          suspend
        end
      else
        @tp = TracePoint.new(@type) do |tp|
          next unless safe_eval tp.binding, @cond
          delete if @oneshot
          suspend
        end
      end
    end

    def enable
      return unless @iseq

      if @type == :line
        @tp.enable(target: @iseq, target_line: @line)
      else
        @tp.enable(target: @iseq)
      end

    rescue ArgumentError
      puts @iseq.disasm # for debug
      raise
    end

    def activate iseq, event, line
      @iseq = iseq
      @type = event
      @line = line
      @path = iseq.absolute_path

      @key = [@path, @line].freeze
      SESSION.rehash_bps

      setup
      enable
    end

    def activate_exact iseq, events, line
      case
      when events.include?(:RUBY_EVENT_CALL)
        # "def foo" line set bp on the beginning of method foo
        activate(iseq, :call, line)
      when events.include?(:RUBY_EVENT_LINE)
        activate(iseq, :line, line)
      when events.include?(:RUBY_EVENT_RETURN)
        activate(iseq, :return, line)
      when events.include?(:RUBY_EVENT_B_RETURN)
        activate(iseq, :b_return, line)
      when events.include?(:RUBY_EVENT_END)
        activate(iseq, :end, line)
      else
        # not actiavated
      end
    end

    NearestISeq = Struct.new(:iseq, :line, :events)

    def try_activate
      nearest = nil # NearestISeq

      ObjectSpace.each_iseq{|iseq|
        if (iseq.absolute_path || iseq.path) == self.path &&
            iseq.first_lineno <= self.line &&
            iseq.type != :ensure # ensure iseq is copied (duplicated)

          iseq.traceable_lines_norec(line_events = {})
          lines = line_events.keys.sort

          if !lines.empty? && lines.last >= line
            nline = lines.bsearch{|l| line <= l}
            events = line_events[nline]

            next if events == [:RUBY_EVENT_B_CALL]

            if @hook_call &&
               events.include?(:RUBY_EVENT_CALL) &&
               self.line == iseq.first_lineno
              nline = iseq.first_lineno
            end

            if !nearest || ((line - nline).abs < (line - nearest.line).abs)
              nearest = NearestISeq.new(iseq, nline, events)
            else
              if @hook_call && nearest.iseq.first_lineno <= iseq.first_lineno
                if (nearest.line > line && !nearest.events.include?(:RUBY_EVENT_CALL)) ||
                   (events.include?(:RUBY_EVENT_CALL))
                  nearest = NearestISeq.new(iseq, nline, events)
                end
              end
            end
          end
        end
      }

      if nearest
        activate_exact nearest.iseq, nearest.events, nearest.line
      end
    end

    def to_s
      oneshot = @oneshot ? " (oneshot)" : ""

      if @iseq
        "line bp #{@path}:#{@line} (#{@type})#{oneshot}" + super
      else
        "line bp (pending) #{@path}:#{@line}#{oneshot}" + super
      end
    end

    def inspect
      "<#{self.class.name} #{self.to_s}>"
    end
  end

  class CatchBreakpoint < Breakpoint
    def initialize pat
      @pat = pat.freeze
      @key = [:catch, @pat].freeze

      super()
    end

    def setup
      @tp = TracePoint.new(:raise){|tp|
        exc = tp.raised_exception
        exc.class.ancestors.each{|cls|
          suspend if pat === cls.name
        }
      }
    end

    def to_s
      "catch bp #{@pat.inspect}"
    end
  end

  class CheckBreakpoint < Breakpoint
    def initialize expr
      @expr = expr.freeze
      @key = [:check, @expr].freeze

      super()
    end

    def setup
      @tp = TracePoint.new(:line){|tp|
        next if tp.path.start_with? __dir__
        next if tp.path.start_with? '<internal:'

        if safe_eval tp.binding, @expr
          suspend
        end
      }
    end

    def to_s
      "check bp: #{@expr}"
    end
  end

  class WatchExprBreakpoint < Breakpoint
    def initialize expr, current
      @expr = expr.freeze
      @key = [:watch, @expr].freeze

      @current = current
      super()
    end

    def watch_eval b
      result = b.eval(@expr)
      if result != @current
        begin
          @prev = @current
          @current = result
          suspend
        ensure
          remove_instance_variable(:@prev)
        end
      end
    rescue Exception => e
      false
    end

    def setup
      @tp = TracePoint.new(:line, :return, :b_return){|tp|
        next if tp.path.start_with? __dir__
        next if tp.path.start_with? '<internal:'

        watch_eval(tp.binding)
      }
    end

    def to_s
      if defined? @prev
        "watch bp: #{@expr} = #{@prev} -> #{@current}"
      else
        "watch bp: #{@expr} = #{@current}"
      end
    end
  end

  class MethodBreakpoint < Breakpoint
    attr_reader :sig_method_name, :method

    def initialize b, klass_name, op, method_name, cond
      @sig_klass_name = klass_name
      @sig_op = op
      @sig_method_name = method_name
      @klass_eval_binding = b

      @klass = nil
      @method = nil
      @cond = cond
      @key = "#{klass_name}#{op}#{method_name}".freeze

      super(false)
    end

    def setup
      if @cond
        @tp = TracePoint.new(:call){|tp|
          next unless safe_eval tp.binding, @cond
          suspend
        }
      else
        @tp = TracePoint.new(:call){|tp|
          suspend
        }
      end
    end

    def eval_class_name
      return @klass if @klass
      @klass = @klass_eval_binding.eval(@sig_klass_name)
      @klass_eval_binding = nil
      @klass
    end

    def search_method
      case @sig_op
      when '.'
        @method = @klass.method(@sig_method_name)
      when '#'
        @method = @klass.instance_method(@sig_method_name)
      else
        raise "Unknown op: #{@sig_op}"
      end
    end

    def enable quiet: false
      eval_class_name
      search_method

      begin
        retried = false
        @tp.enable(target: @method)

      rescue ArgumentError => e
        raise if retried
        retried = true

        # maybe C method
        @klass.module_eval do
          orig_name = @sig_method_name + '__orig__'
          alias_method orig_name, @sig_method_name
          define_method(@sig_method_name) do |*args|
            send(orig_name, *args)
          end
        end
        retry
      end
    rescue Exception
      raise unless quiet
    end

    def sig
      @key
    end

    def to_s
      if @method
        "method bp: #{sig}"
      else
        "method bp (pending): #{sig}"
      end + super
    end
  end
end

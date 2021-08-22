# frozen_string_literal: true

module DEBUGGER__
  class Tracer
    include SkipPathHelper
    include Color

    def colorize(str, color)
      # don't colorize trace sent into a file
      if @into
        str
      else
        super
      end
    end

    attr_reader :type

    def initialize ui, pattern: nil, into: nil
      if /\ADEBUGGER__::(([A-Z][a-z]+?)[A-Z][a-z]+)/ =~ self.class.name
        @name = $1
        @type = $2.downcase
      end

      setup

      if pattern
        @pattern = Regexp.compile(pattern)
      else
        @pattern = nil
      end

      if @into = into
        @output = File.open(into, 'w')
        @output.puts "PID:#{Process.pid} #{self}"
      else
        @output = ui
      end

      enable
    end

    def close
    end

    def header depth
      "DEBUGGER (trace/#{@type}) \#th:#{Thread.current.instance_variable_get(:@__thread_client_id)} \#depth:#{'%-2d'%depth}"
    end

    def enable
      @tracer.enable
    end

    def disable
      @tracer.disable
    end

    def description
      nil
    end

    def to_s
      s = "#{@name}#{description} (#{@tracer.enabled? ? 'enabled' : 'disabled'})"
      s += " with pattern #{@pattern}" if @pattern
      s += " into: #{@into}" if @into
      s
    end

    def skip? tp
      if tp.path.start_with?(__dir__) ||
         tp.path.start_with?('<internal:') ||
         ThreadClient.current.management? ||
         (@pattern && !tp.path.match?(@pattern) && !tp.method_id&.match?(@pattern)) ||
         skip_path?(tp.path)
        true
      else
        false
      end
    end

    def out tp, msg = nil, depth = caller.size - 1
      location_str = colorize("#{tp.path}:#{tp.lineno}", [:GREEN])
      buff = "#{header(depth)}#{msg} at #{location_str}"

      if false # TODO: Ractor.main?
        ThreadClient.current.on_trace self.object_id, buff
      else
        @output.puts buff
      end
    end

    def puts msg
      @output.puts msg
    end

    def minfo tp
      klass = tp.defined_class

      if klass.singleton_class?
        "#{tp.self}.#{tp.method_id}"
      else
        "#{klass}\##{tp.method_id}"
      end
    end
  end

  class LineTracer < Tracer
    def setup
      @tracer = TracePoint.new(:line){|tp|
        next if skip?(tp)
        # pp tp.object_id, caller(0)
        out tp
      }
    end
  end

  class CallTracer < Tracer
    def setup
      @tracer = TracePoint.new(:a_call, :a_return){|tp|
        next if skip?(tp)

        depth = caller.size
        sp = ' ' * depth

        call_identifier_str =
          if tp.defined_class
            minfo(tp)
          else
            "block"
          end

        call_identifier_str = colorize_blue(call_identifier_str)

        case tp.event
        when :call, :c_call, :b_call
          depth += 1 if tp.event == :c_call
          out tp, ">#{sp}#{call_identifier_str}", depth
        when :return, :c_return, :b_return
          depth += 1 if tp.event == :c_return
          return_str = colorize_magenta(DEBUGGER__.short_inspect(tp.return_value))
          out tp, "<#{sp}#{call_identifier_str} #=> #{return_str}", depth
        end
      }
    end
  end

  class RaiseTracer < Tracer
    def setup
      @tracer = TracePoint.new(:raise) do |tp|
        next if skip?(tp)

        exc = tp.raised_exception

        out tp, " #{colorize_magenta(exc.inspect)}"
      rescue Exception => e
        p e
      end
    end
  end

  class PassTracer < Tracer
    def initialize ui, obj_id, obj_inspect, **kw
      @obj_id = obj_id
      @obj_inspect = obj_inspect
      super(ui, **kw)
    end

    def description
      " for #{@obj_inspect}"
    end

    def colorized_obj_inspect
      colorize_magenta(@obj_inspect)
    end

    def setup
      @tracer = TracePoint.new(:a_call){|tp|
        next if skip?(tp)

        if tp.self.object_id == @obj_id
          klass = tp.defined_class
          method = tp.method_id
          method_info =
            if klass.singleton_class?
              if tp.self.is_a?(Class)
                ".#{method} (#{klass}.#{method})"
              else
                ".#{method}"
              end
            else
              "##{method} (#{klass}##{method})"
            end

          out tp, " #{colorized_obj_inspect} receives #{colorize_blue(method_info)}"
        else
          b = tp.binding
          method_info = colorize_blue(minfo(tp))

          tp.parameters.each{|type, name|
            next unless name

            colorized_name = colorize_cyan(name)

            case type
            when :req, :opt, :key, :keyreq
              if b.local_variable_get(name).object_id == @obj_id
                out tp, " #{colorized_obj_inspect} is used as a parameter #{colorized_name} of #{method_info}"
              end
            when :rest
              next name == :"*"

              ary = b.local_variable_get(name)
              ary.each{|e|
                if e.object_id == @obj_id
                  out tp, " #{colorized_obj_inspect} is used as a parameter in #{colorized_name} of #{method_info}"
                end
              }
            when :keyrest
              next if name == :'**'
              h = b.local_variable_get(name)
              h.each{|k, e|
                if e.object_id == @obj_id
                  out tp, " #{colorized_obj_inspect} is used as a parameter in #{colorized_name} of #{method_info}"
                end
              }
            end
          }
        end
      }
    end
  end
end


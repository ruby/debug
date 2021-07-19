
module DEBUGGER__
  class Tracer
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

    def header depth = caller.size
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
      s << " with pattern #{@pattern}" if @pattern
      s << " into: #{@into}" if @into
      s
    end

    def skip? tp
      if tp.path.start_with?(__dir__) ||
         tp.path.start_with?('<internal:') ||
         (@pattern && !tp.path.match?(@pattern) && !tp.method_id.match?(@pattern))
        true
      else
        false
      end
    end

    def out msg
      if false # TODO: Ractor.main?
        ThreadClient.current.on_trace self.object_id, msg
      else
        @output.puts msg
      end
    end

    def puts msg
      @output.puts msg
    end
  end

  class LineTracer < Tracer
    def setup
      @tracer = TracePoint.new(:line){|tp|
        next if skip?(tp)
        # pp tp.object_id, caller(0)
        out "#{header} at #{tp.path}:#{tp.lineno}"
      }
    end
  end

  class CallTracer < Tracer
    def setup
      @tracer = TracePoint.new(:a_call, :a_return){|tp|
        next if skip?(tp)

        depth = caller.size
        sp = ' ' * depth
        header = header(depth)

        case tp.event
        when :call, :c_call
          out "#{header}>#{sp}#{tp.defined_class}\##{tp.method_id} at #{tp.path}:#{tp.lineno}"
        when :return, :c_return
          out "#{header}<#{sp}#{tp.defined_class}\##{tp.method_id} at #{tp.path}:#{tp.lineno} (\#=> #{tp.return_value.inspect})"
        when :b_call
          out "#{header}>#{sp}block at #{tp.path}:#{tp.lineno}"
        when :b_return
          out "#{header}<#{sp}block at #{tp.path}:#{tp.lineno} (\#=> #{tp.return_value.inspect})"
        end
      }
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

    def setup
      @tracer = TracePoint.new(:a_call){|tp|
        next if skip?(tp)

        if tp.self.object_id == @obj_id
          out "#{header} object_id:#{@obj_id} is used as a receiver of #{tp.defined_class}\##{tp.method_id} at #{tp.path}:#{tp.lineno}"
        else
          b = tp.binding
          tp.parameters.each{|type, name|
            case type
            when :req, :opt
              next unless name

              if b.local_variable_get(name).object_id == @obj_id
                out "#{header} `#{@obj_inspect}` is used as a parameter `#{name}` of #{tp.defined_class}\##{tp.method_id} at #{tp.path}:#{tp.lineno}"
              end

            when :rest
              next unless name
              ary = b.local_variable_get(name)
              ary.each{|e|
                if e.object_id == @obj_id
                  out "#{header} `#{@obj_inspect}` is used as a parameter in `#{name}` of \##{tp.method_id} at #{tp.path}:#{tp.lineno}"
                end
              }

            when :key, :keyreq
              next unless name

              if b.local_variable_get(name).object_id == @obj_id
                out "#{header} `#{@obj_inspect}` is used as a parameter `#{name}` of #{tp.defined_class}\##{tp.method_id} at #{tp.path}:#{tp.lineno}"
              end
            when :keyrest
              next unless name
              h = b.local_variable_get(name)
              h.each{|k, e|
                if e.object_id == @obj_id
                  out "#{header} `#{@obj_inspect}` is used as a parameter in `#{name}` of \##{tp.method_id} at #{tp.path}:#{tp.lineno}"
                end
              }
            end
          }
        end
      }
    end
  end
end


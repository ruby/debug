# frozen_string_literal: true

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
      s << " with pattern #{@pattern}" if @pattern
      s << " into: #{@into}" if @into
      s
    end

    def skip? tp
      if tp.path.start_with?(__dir__) ||
         tp.path.start_with?('<internal:') ||
         (@pattern && !tp.path.match?(@pattern) && !tp.method_id.match?(@pattern)) ||
         ((paths = CONFIG[:skip_path]) && !paths.empty? && paths.any?{|path| tp.path.match?(path)})
        true
      else
        false
      end
    end

    def out tp, msg = nil, depth = caller.size - 1
      buff = "#{header(depth)}#{msg} at #{tp.path}:#{tp.lineno}"

      if false # TODO: Ractor.main?
        ThreadClient.current.on_trace self.object_id, buff
      else
        @output.puts buff
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

        case tp.event
        when :call
          out tp, ">#{sp}#{tp.defined_class}\##{tp.method_id}", depth
        when :return
          out tp, "<#{sp}#{tp.defined_class}\##{tp.method_id} \#=> #{tp.return_value.inspect}", depth
        when :c_call
          out tp, ">#{sp} #{tp.defined_class}\##{tp.method_id}", depth + 1
        when :c_return
          out tp, "<#{sp} #{tp.defined_class}\##{tp.method_id} \#=> #{tp.return_value.inspect}", depth + 1
        when :b_call
          out tp, ">#{sp}block", depth
        when :b_return
          out tp, "<#{sp}block \#=> #{tp.return_value.inspect}", depth
        end
      }
    end
  end

  class RaiseTracer < Tracer
    def setup
      @tracer = TracePoint.new(:raise) do |tp|
        next if skip?(tp)

        exc = tp.raised_exception

        out tp, " #{exc.inspect}"
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

    def minfo tp
      klass = tp.defined_class

      if klass.singleton_class?
        "#{tp.self}.#{tp.method_id}"
      else
        "#{klass}\##{tp.method_id}"
      end
    end

    def setup
      @tracer = TracePoint.new(:a_call){|tp|
        next if skip?(tp)

        if tp.self.object_id == @obj_id
          out tp, "`#{@obj_inspect}` is used as a receiver of #{minfo(tp)}"
        else
          b = tp.binding
          tp.parameters.each{|type, name|
            case type
            when :req, :opt
              next unless name

              if b.local_variable_get(name).object_id == @obj_id
                out tp, " `#{@obj_inspect}` is used as a parameter `#{name}` of #{minfo(tp)}"
              end

            when :rest
              next unless name && name != :"*"

              ary = b.local_variable_get(name)
              ary.each{|e|
                if e.object_id == @obj_id
                  out tp, " `#{@obj_inspect}` is used as a parameter in `#{name}` of #{minfo(tp)}"
                end
              }

            when :key, :keyreq
              next unless name

              if b.local_variable_get(name).object_id == @obj_id
                out tp, " `#{@obj_inspect}` is used as a parameter `#{name}` of #{minfo(tp)}"
              end
            when :keyrest
              next unless name
              h = b.local_variable_get(name)
              h.each{|k, e|
                if e.object_id == @obj_id
                  out tp, " `#{@obj_inspect}` is used as a parameter in `#{name}` of #{minfo(tp)}"
                end
              }
            end
          }
        end
      }
    end
  end
end


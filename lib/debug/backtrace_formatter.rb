module DEBUGGER__
  class BacktraceFormatter
    attr_reader :frames

    def initialize(frames)
      @frames = frames
    end

    def formatted_traces(max)
      traces = []
      max += 1 if @frames.size == max + 1
      max.times do |i|
        break if i >= @frames.size
        traces << formatted_trace(i)
      end

      traces
    end

    def formatted_trace(i)
      frame = @frames[i]
      result = "#{frame.call_identifier_str} at #{frame.location_str}"
      result += " #=> #{frame.return_str}" if frame.return_str
      result
    end
  end
end

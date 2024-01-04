# frozen_string_literal: true

require "pp"

module DEBUGGER__
  class LimitedPP
    SHORT_INSPECT_LENGTH = 40

    def self.pp(obj, max = 80)
      out = self.new(max)
      catch out do
        ::PP.singleline_pp(obj, out)
      end
      out.buf
    end

    attr_reader :buf

    def initialize max
      @max = max
      @cnt = 0
      @buf = String.new
    end

    def <<(other)
      @buf << other

      if @buf.size >= @max
        @buf = @buf[0..@max] + '...'
        throw self
      end
    end

    def self.safe_inspect obj, max_length: SHORT_INSPECT_LENGTH, short: false
      if short
        LimitedPP.pp(obj, max_length)
      else
        obj.inspect
      end
    rescue NoMethodError => e
      klass, oid = M_CLASS.bind_call(obj), M_OBJECT_ID.bind_call(obj)
      if obj == (r = e.receiver)
        "<\##{klass.name}#{oid} does not have \#inspect>"
      else
        rklass, roid = M_CLASS.bind_call(r), M_OBJECT_ID.bind_call(r)
        "<\##{klass.name}:#{roid} contains <\##{rklass}:#{roid} and it does not have #inspect>"
      end
    rescue Exception => e
      "<#inspect raises #{e.inspect}>"
    end
  end
end

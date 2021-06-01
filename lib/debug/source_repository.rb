require 'irb/color' # IRB::Color.colorize_code

module DEBUGGER__
  class SourceRepository
    SrcInfo = Struct.new(:src, :colored)

    def initialize
      @files = {} # filename => SrcInfo
    end

    def add iseq, src
      if (path = iseq.absolute_path) && File.exist?(path)
        add_path path
      else
        add_iseq iseq, src
      end
    end

    def all_iseq iseq, rs = []
      rs << iseq
      iseq.each_child{|ci|
        all_iseq(ci, rs)
      }
      rs
    end

    def add_iseq iseq, src
      line = iseq.first_line
      if line > 1
        src = ("\n" * (line - 1)) + src
      end
      si = SrcInfo.new(src.lines)

      all_iseq(iseq).each{|e|
        e.instance_variable_set(:@debugger_si, si)
        e.freeze
      }
    end

    def add_path path
      begin
        src = File.read(path)
        src = src.gsub("\r\n", "\n") # CRLF -> LF
        @files[path] = SrcInfo.new(src.lines)
      rescue SystemCallError
      end
    end

    def get_si iseq
      return unless iseq

      if iseq.instance_variable_defined?(:@debugger_si)
        iseq.instance_variable_get(:@debugger_si)
      elsif @files.has_key?(path = iseq.absolute_path)
        @files[path]
      elsif path
        add_path(path)
      end
    end

    def get iseq
      if si = get_si(iseq)
        si.src
      end
    end

    def get_colored iseq
      if si = get_si(iseq)
        si.colored || begin
          si.colored = IRB::Color.colorize_code(si.src.join).lines
        end
      end
    end
  end
end

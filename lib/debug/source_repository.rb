require 'irb/color' # IRB::Color.colorize_code

module DEBUGGER__
  class SourceRepository
    def initialize
      @files = {} # filename => [src, iseq]
      @color_files = {}
    end

    def add iseq, src
      path = iseq.absolute_path
      path = '-e' if iseq.path == '-e'
      add_path path, src: src
    end

    def add_path path, src: nil
      case
      when src
        if path && File.file?(path)
          path = '(eval)' + path
          src = nil
        end
      when path == '-e'
      when path
        begin
          src = File.read(path)
        rescue SystemCallError
        end
      else
        src = nil
      end

      if src
        src = src.gsub("\r\n", "\n") # CRLF -> LF
        @files[path] = src.lines
      end
    end

    def get path
      if @files.has_key? path
        @files[path]
      else
        add_path path
      end
    end

    def get_colored path
      if src_lines = @color_files[path]
        return src_lines
      else
        if src_lines = get(path)
          @color_files[path] = IRB::Color.colorize_code(src_lines.join).lines
        end
      end
    end
  end
end

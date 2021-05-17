module DEBUGGER__
  class SourceRepository
    def initialize
      @files = {} # filename => [src, iseq]
    end

    def add iseq, src
      path = iseq.absolute_path
      path = '-e' if iseq.path == '-e'

      case
      when src
        if  File.file?(path)
          path = '(eval)' + path
          src = nil
        end
      when path = iseq.absolute_path
        begin
          src = File.read(path)
        rescue SystemCallError
        end
      when iseq.path == '-e'
        path = '-e'
      else
        src = nil
      end

      @files[path] = src.lines if src
    end

    def get path
      @files[path]
    end
  end
end

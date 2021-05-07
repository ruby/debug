module DEBUGGER__
  class SourceRepository
    def initialize
      @files = {} # filename => [src, iseq]
    end

    def add iseq, src
      path = iseq.absolute_path
      path = '-e' if iseq.path == '-e'

      case
      when path = iseq.absolute_path
        src = File.read(path)
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

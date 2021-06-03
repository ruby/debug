require "irb/color_printer"

module DEBUGGER__
  module Color
    def colorize str, color
      if CONFIG[:use_colorize]
        IRB::Color.colorize str, color
      else
        str
      end
    end

    def colored_inspect(obj)
      if CONFIG[:use_colorize]
        IRB::ColorPrinter.pp(obj, "")
      else
        obj.pretty_inspect
      end
    end

    def colorize_cyan(str)
      colorize(str, [:CYAN, :BOLD])
    end

    def colorize_blue(str)
      colorize(str, [:BLUE, :BOLD])
    end
  end
end

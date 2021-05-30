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
    rescue => ex
      err_msg = "(rescued #{ex.inspect} during inspection)"
      string_result = obj.to_s rescue nil

      # don't colorize the string here because it's not from user's application
      if string_result
        "#{string_result} #{err_msg}"
      else
        err_msg
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

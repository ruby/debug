# frozen_string_literal: true

begin
  require 'irb/color'
  require "irb/color_printer"
rescue LoadError
  warn "DEBUGGER: can not load newer irb for coloring. Write 'gem \"debug\" in your Gemfile."
end

module DEBUGGER__
  module Color
    if defined? IRB::Color.colorize
      def colorize str, color
        if !CONFIG[:no_color]
          IRB::Color.colorize str, color
        else
          str
        end
      end
    else
      def colorize str, color
        str
      end
    end

    if defined? IRB::ColorPrinter.pp
      def color_pp obj, width = nil
        if !CONFIG[:no_color]
          IRB::ColorPrinter.pp(obj, "".dup, width)
        else
          obj.pretty_inspect
        end
      end
    else
      def color_pp obj
        obj.pretty_inspect
      end
    end

    def colored_inspect obj, no_color: false
      if !no_color
        color_pp obj
      else
        obj.pretty_inspect
      end
    rescue => ex
      err_msg = "#{ex.inspect} rescued during inspection"
      string_result = obj.to_s rescue nil

      # don't colorize the string here because it's not from user's application
      if string_result
        %Q{"#{string_result}" from #to_s because #{err_msg}}
      else
        err_msg
      end
    end

    if defined? IRB::Color.colorize_code
      def colorize_code code
        IRB::Color.colorize_code(code)
      end
    else
      def colorize_code code
        code
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

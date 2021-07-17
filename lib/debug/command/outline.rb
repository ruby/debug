# frozen_string_literal: true

module DEBUGGER__
  module Command
    class Outline
      class << self
        def execute(current_frame, obj, output)
          o = Output.new(output)

          locals = current_frame.binding.local_variables
          klass  = (obj.class == Class || obj.class == Module ? obj : obj.class)

          o.dump("constants", obj.constants) if obj.respond_to?(:constants)
          dump_methods(o, klass, obj)
          o.dump("instance variables", obj.instance_variables)
          o.dump("class variables", klass.class_variables)
          o.dump("locals", locals)
        end

        def dump_methods(o, klass, obj)
          singleton_class = begin obj.singleton_class; rescue TypeError; nil end
          maps = class_method_map((singleton_class || klass).ancestors)
          maps.each do |mod, methods|
            name = mod == singleton_class ? "#{klass}.methods" : "#{mod}#methods"
            o.dump(name, methods)
          end
        end

        def class_method_map(classes)
          dumped = Array.new
          classes.reject { |mod| mod >= Object }.map do |mod|
            methods = mod.public_instance_methods(false).select do |m|
              dumped.push(m) unless dumped.include?(m)
            end
            [mod, methods]
          end.reverse
        end
      end

      class Output
        include Color

        MARGIN = "  "

        def initialize(output)
          @output = output
          @line_width = screen_width - MARGIN.length # right padding
        end

        def dump(name, strs)
          strs = strs.sort
          return if strs.empty?

          line = "#{colorize_blue(name)}: "

          # Attempt a single line
          if fits_on_line?(strs, cols: strs.size, offset: "#{name}: ".length)
            line += strs.join(MARGIN)
            @output << line
            return
          end

          # Multi-line
          @output << line

          # Dump with the largest # of columns that fits on a line
          cols = strs.size
          until fits_on_line?(strs, cols: cols, offset: MARGIN.length) || cols == 1
            cols -= 1
          end
          widths = col_widths(strs, cols: cols)
          strs.each_slice(cols) do |ss|
            @output << ss.map.with_index { |s, i| "#{MARGIN}%-#{widths[i]}s" % s }.join
          end
        end

        private

        def fits_on_line?(strs, cols:, offset: 0)
          width = col_widths(strs, cols: cols).sum + MARGIN.length * (cols - 1)
          width <= @line_width - offset
        end

        def col_widths(strs, cols:)
          cols.times.map do |col|
            (col...strs.size).step(cols).map do |i|
              strs[i].length
            end.max
          end
        end

        def screen_width
          SESSION.width
        rescue Errno::EINVAL # in `winsize': Invalid argument - <STDIN>
          80
        end
      end
      private_constant :Output
    end
  end
end

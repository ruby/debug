
module DEBUGGER__
  FrameInfo = Struct.new(:location, :self, :binding, :iseq, :class, :frame_depth,
                          :has_return_value, :return_value, :show_line)


  # extend FrameInfo with debug.so
  if File.exist? File.join(__dir__, 'debug.so')
    require_relative 'debug.so'
  else
    require "debug/debug"
  end

  class FrameInfo
    HOME = ENV['HOME'] ? (ENV['HOME'] + '/') : nil

    def path
      location.path
    end

    def realpath
      location.absolute_path
    end

    def pretty_path
      use_short_path = ::DEBUGGER__::CONFIG[:use_short_path]

      case
      when use_short_path && path.start_with?(dir = ::DEBUGGER__::CONFIG["rubylibdir"] + '/')
        path.sub(dir, '$(rubylibdir)/')
      when use_short_path && Gem.path.any? do |gp|
          path.start_with?(dir = gp + '/gems/')
        end
        path.sub(dir, '$(Gem)/')
      when HOME && path.start_with?(HOME)
        path.sub(HOME, '~/')
      else
        path
      end
    end

    def file_lines
      SESSION.source(realpath || path)
    end

    def colorize str, color
      if CONFIG[:use_colorize]
        IRB::Color.colorize str, color
      else
        str
      end
    end

    def colorize_blue(str)
      colorize(str, [:BLUE, :BOLD])
    end

    def call_identifier_str
      if binding && iseq
        if iseq.type == :block
          if (argc = iseq.argc) > 0
            args = parameters_info(argc)
            args_str = " {|" + assemble_arguments(args) + "|}"
          end

          _, _, block_loc = location.label.split(" ")

          "#{colorize_blue("block")}#{args_str} in #{colorize_blue(block_loc)}"
        elsif callee = binding.eval('__callee__', __FILE__, __LINE__)
          if (argc = iseq.argc) > 0
            args = parameters_info(argc)
            args_str = " (" + assemble_arguments(args) + ")"
          end

          ci = colorize_blue("#{klass_sig}#{callee}")
          "#{ci}#{args_str}"
        else
          location.label
        end
      else
        "[C] #{klass_sig}#{location.base_label}"
      end
    end

    def return_str
      if binding && iseq && has_return_value
        short_inspect(return_value)
      end
    end

    def location_str
      "#{pretty_path}:#{location.lineno}"
    end

    private

    SHORT_INSPECT_LENGTH = 40

    def short_inspect obj
      str = obj.inspect
      if str.length > SHORT_INSPECT_LENGTH
        str[0...SHORT_INSPECT_LENGTH] + '...'
      else
        str
      end
    end

    def get_singleton_class obj
      obj.singleton_class # TODO: don't use it
    rescue TypeError
      nil
    end

    def parameters_info(argc)
      vars = iseq.locals[0...argc]
      vars.map{|var|
        begin
          { name: colorize(var, [:CYAN, :BOLD]), value: short_inspect(binding.local_variable_get(var)) }
        rescue NameError, TypeError
          nil
        end
      }
    end

    def assemble_arguments(args)
      args.map do |arg|
        "#{arg[:name]}=#{arg[:value]}"
      end.join(", ")
    end

    def klass_sig
      if self.class == get_singleton_class(self.self)
        "#{self.self}."
      else
        "#{self.class}#"
      end
    end
  end
end

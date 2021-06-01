
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
      SESSION.source(self.iseq)
    end

    def frame_type
      if binding && iseq
        if iseq.type == :block
          :block
        elsif callee
          :method
        else
          :other
        end
      else
        :c
      end
    end

    def block_identifier
      return unless frame_type == :block
      args = parameters_info(iseq.argc)
      _, _, block_loc = location.label.split(" ")
      [block_loc, args]
    end

    def method_identifier
      return unless frame_type == :method
      args = parameters_info(iseq.argc)
      ci = "#{klass_sig}#{callee}"
      [ci, args]
    end

    def c_identifier
      return unless frame_type == :c
      "[C] #{klass_sig}#{location.base_label}"
    end

    def other_identifier
      return unless frame_type == :other
      location.label
    end

    def callee
      @callee ||= binding&.eval('__callee__', __FILE__, __LINE__)
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
          { name: var, value: short_inspect(binding.local_variable_get(var)) }
        rescue NameError, TypeError
          nil
        end
      }.compact
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

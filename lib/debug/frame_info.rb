module DEBUGGER__
  class FrameInfo
    HOME = ENV['HOME'] ? (ENV['HOME'] + '/') : nil

    def path
      location.path
    end

    def pretty_path
      use_short_path = CONFIG[:use_short_path]

      case
      when use_short_path && path.start_with?(dir = RbConfig::CONFIG["rubylibdir"] + '/')
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

    def pretty_location
      " at #{pretty_path}:#{location.lineno}"
    end

    def parameters_info vars
      vars.map{|var|
        begin
          "#{var}=#{short_inspect(binding.local_variable_get(var))}"
        rescue NameError, TypeError
          nil
        end
      }.compact.join(', ')
    end

    def klass_sig
      if self.class == get_singleton_class(self.self)
        "#{self.self}."
      else
        "#{self.class}#"
      end
    end

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

    def to_client_output
      loc_str = pretty_location

      if binding && iseq
        if iseq.type == :block
          if (argc = iseq.argc) > 0
            args = parameters_info iseq.locals[0...argc]
            args_str = "{|#{args}|}"
          end

          label_prefix = location.label.sub('block'){ "block#{args_str}" }
          ci_str = label_prefix
        elsif (callee = binding.eval('__callee__', __FILE__, __LINE__)) && (argc = iseq.argc) > 0
          args = parameters_info iseq.locals[0...argc]
          ksig = klass_sig
          ci_str = "#{ksig}#{callee}(#{args})"
        else
          ci_str = location.label
        end

        if has_return_value
          return_str = " #=> #{short_inspect(return_value)}"
        end
      else
        ksig = klass_sig
        callee = location.base_label
        ci_str = "[C] #{ksig}#{callee}"
      end

      "#{ci_str}#{loc_str}#{return_str}"
    end
  end
end

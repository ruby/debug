# frozen_string_literal: true

module DEBUGGER__
  module Reflection
    module_function def instance_variables_of(o)
      M_INSTANCE_VARIABLES.bind_call(o)
    end

    module_function def instance_variable_get_from(o, name)
      M_INSTANCE_VARIABLE_GET.bind_call(o, name)
    end

    module_function def class_of(o)
      M_CLASS.bind_call(o)
    end

    module_function def singleton_class_of(o)
      M_SINGLETON_CLASS.bind_call(o)
    end

    module_function def is_kind_of?(object, type)
      M_KIND_OF_P.bind_call(object, type)
    end

    module_function def responds_to?(object, message, include_all: false)
      M_RESPOND_TO_P.bind_call(object, message, include_all)
    end

    module_function def method_of(type, method_name)
      M_METHOD.bind_call(type, method_name)
    end

    module_function def object_id_of(o)
      M_OBJECT_ID.bind_call(o)
    end

    module_function def name_of(type)
      M_NAME.bind_call(type)
    end

    M_INSTANCE_VARIABLES = Kernel.instance_method(:instance_variables)
    M_INSTANCE_VARIABLE_GET = Kernel.instance_method(:instance_variable_get)
    M_CLASS = Kernel.instance_method(:class)
    M_SINGLETON_CLASS = Kernel.instance_method(:singleton_class)
    M_KIND_OF_P = Kernel.instance_method(:kind_of?)
    M_RESPOND_TO_P = Kernel.instance_method(:respond_to?)
    M_METHOD = Kernel.instance_method(:method)
    M_OBJECT_ID = Kernel.instance_method(:object_id)
    M_NAME = Module.instance_method(:name)

    private_constant(
      :M_INSTANCE_VARIABLES,
      :M_INSTANCE_VARIABLE_GET,
      :M_CLASS,
      :M_SINGLETON_CLASS,
      :M_KIND_OF_P,
      :M_RESPOND_TO_P,
      :M_METHOD,
      :M_OBJECT_ID,
      :M_NAME,
    )
  end
end

# for Ruby 2.6 compatibility
unless UnboundMethod.method_defined?(:bind_call)
  class UnboundMethod
    def bind_call(receiver, *args, &block)
      bind(receiver).call(*args, &block)
    end
  end
end

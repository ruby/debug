# frozen_string_literal: true

require_relative 'variable_inspector'

module DEBUGGER__
  class Variable
    attr_reader :name, :value

    def initialize(name:, value:, internal: false)
      @name = name
      @value = value
      @is_internal = internal
    end

    def internal?
      @is_internal
    end

    def self.internal name:, value:
      new(name: name, value: value, internal: true)
    end

    def inspect_value
      @inspect_value ||= if VariableInspector::NaiveString === @value
        @value.str.dump
      else
        VariableInspector.value_inspect(@value)
      end
    end

    def value_type_name
      klass = M_CLASS.bind_call(@value)

      begin
        M_NAME.bind_call(klass) || klass.to_s
      rescue Exception => e
        "<Error: #{e.message} (#{e.backtrace.first}>"
      end
    end

    def ==(other)
      other.instance_of?(self.class) &&
        @name == other.name &&
        @value == other.value &&
        @is_internal == other.internal?
    end

    def inspect
      "#<Variable name=#{@name.inspect} value=#{inspect_value}#{@is_internal ? " internal" : ""}>"
    end

    # TODO: Replace with Reflection helpers once they are merged
    # https://github.com/ruby/debug/pull/1002
    M_CLASS = method(:class).unbind
  end
end

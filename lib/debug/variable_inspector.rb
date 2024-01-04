# frozen_string_literal: true

require_relative 'variable'
require_relative 'limited_pp'

module DEBUGGER__
  class VariableInspector
    def indexed_members_of(obj, start:, count:)
      return [] if start > (obj.length - 1)

      (start...(start + count)).map do |i|
        Variable.new(name: i.to_s, value: obj[i])
      end
    end

    def named_members_of(obj)
      return [] if NaiveString === obj

      members = case obj
      when Hash then obj.map { |k, v| Variable.new(name: value_inspect(k), value: v) }
      when Struct then obj.members.map { |name| Variable.new(name: name, value: obj[name]) }
      when String
        members = [
          Variable.internal(name: '#length', value: obj.length),
          Variable.internal(name: '#encoding', value: obj.encoding),
        ]

        printed_str = value_inspect(obj)
        members << Variable.internal(name: "#dump", value: NaiveString.new(obj)) if printed_str.end_with?('...')

        members
      when Class, Module then [Variable.internal(name: "%ancestors", value: obj.ancestors[1..])]
      when Range then [
        Variable.internal(name: "#begin", value: obj.begin),
        Variable.internal(name: "#end", value: obj.end),
      ]
      else []
      end

      ivars_members = M_INSTANCE_VARIABLES.bind_call(obj).sort.map do |iv|
        Variable.new(name: iv, value: M_INSTANCE_VARIABLE_GET.bind_call(obj, iv))
      end

      members.unshift Variable.internal(name: '#class', value: M_CLASS.bind_call(obj))
      members.concat(ivars_members)

      members
    end

    private

    def value_inspect(obj, short: true)
      self.class.value_inspect(obj, short: short)
    end

    def self.value_inspect(obj, short: true)
      # TODO: max length should be configurable?
      str = LimitedPP.safe_inspect obj, short: short, max_length: MAX_LENGTH

      if str.encoding == Encoding::UTF_8
        str.scrub
      else
        str.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
      end
    end

    MAX_LENGTH = 180

    # TODO: Replace with Reflection helpers once they are merged
    # https://github.com/ruby/debug/pull/1002
    M_INSTANCE_VARIABLES = method(:instance_variables).unbind
    M_INSTANCE_VARIABLE_GET = method(:instance_variable_get).unbind
    M_CLASS = method(:class).unbind

    class NaiveString
      attr_reader :str
      def initialize str
        @str = str
      end

      def == other
        other.instance_of?(self.class) && @str == other.str
      end
    end
  end
end

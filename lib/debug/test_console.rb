# frozen_string_literal: true

require_relative 'console'

module DEBUGGER__
  #
  # Custom interface for easier associations
  #
  class TestUI_Console < UI_Console
    attr_accessor :input, :test_block

    def quit n
      nil
    end

    def initialize
      @input = []
      super
    end

    def clear
      @input = []
    end

    def readline
      line = super
      return line unless line.nil? && test_block

      test_block.call
      self.test_block = nil
    end

    def readline_body
      cmd = input.shift
      cmd.is_a?(Proc) ? cmd.call : cmd
    end

    private

    def prepare(str)
      return str.map(&:to_s) if str.respond_to?(:map)

      str.to_s.split("\n")
    end
  end
end

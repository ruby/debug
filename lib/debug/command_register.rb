module DEBUGGER__
  class Command
    attr_reader :names, :session_operation

    def initialize(names)
      @names = names
      @session_operation = nil
    end

    def in_session(&block)
      @session_operation = block
    end
  end

  class << self
    def regsiter_command(*names, &block)
      command = Command.new(names)
      block.call(command)
      @registered_commands ||= []
      @registered_commands << command
    end

    def regsiter_commands
      @registered_commands ||= []
    end
  end
end

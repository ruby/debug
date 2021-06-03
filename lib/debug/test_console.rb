# frozen_string_literal: true

require 'json'

module DEBUGGER__
  #
  # Custom UI_Console to make tests easier
  #
  module TestUI_Console
    def initialize
      @backlog = []
    end

    def ask prompt
      setup_interrupt do
        puts prompt
        (gets || '').strip
      end
    end

    def puts str = nil
      case str
      when String
        @backlog.push(str)
      when Hash
        @internal_info = str
      end
      super(str)
    end

    def readline_body
      unless @internal_info.empty?
        @internal_info[:backlog] = @backlog
        $stdout.puts "INTERNAL_INFO: #{JSON.generate(@internal_info)}"
        @backlog = []
      end
      readline_setup
      Readline.readline("\n(rdbg)\n", true)
    end
  end
end

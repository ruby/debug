# frozen_string_literal: true

require 'json'

module DEBUGGER__
  #
  # Custom UI_Console to make tests easier
  #
  module TestUI_Console

    def ask prompt
      setup_interrupt do
        puts prompt
        (gets || '').strip
      end
    end

    def puts str = nil
      @internal_info = str
      super(str)
    end

    def readline_body
      $stdout.puts "INTERNAL_INFO: #{JSON.generate(@internal_info)}" unless @internal_info.empty?
      readline_setup
      Readline.readline("\n(rdbg)\n", true)
    end
  end
end

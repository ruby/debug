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

    def readline_body
      readline_setup
      Readline.readline("\n(rdbg)\n", true)
    end
  end
end

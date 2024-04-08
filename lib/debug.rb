# frozen_string_literal: true

require_relative 'debug/prelude'

module DEBUGGER__
  def self.step_in(&block)
    require "debug/session"

    # If session.rb doesn't early return, we can then call the method it defines.
    if defined?(Session)
      start no_sigint_hook: true, nonstop: true
      step_in(&block)
    # Otherwise, we call the block without stepping in.
    else
      yield
    end
  end

  def self.start(**kw)
    require "debug/session"

    # If session.rb doesn't early return, we can then call the method it defines.
    if defined?(Session)
      start(**kw)
    end
  end
end

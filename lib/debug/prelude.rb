#
# put the following line in .bash_profile
#   export RUBYOPT="-r .../debug/prelude $(RUBYOPT)"
#
module Kernel
  def debugger(*a, up_level: 0, **kw)
    begin
      require_relative 'frame_info'
      require_relative 'version'

      if !defined?(::DEBUGGER__::SO_VERSION) || ::DEBUGGER__::VERSION != ::DEBUGGER__::SO_VERSION
        ::Object.send(:remove_const, :DEBUGGER__)
        raise LoadError
      end
      require_relative 'session'
      up_level += 1
    rescue LoadError
      $LOADED_FEATURES.delete_if{|e|
        e.start_with?(__dir__) || e.end_with?('debug/debug.so')
      }
      require 'debug/session'
      up_level += 1
    end

    ::DEBUGGER__::start no_sigint_hook: true, nonstop: true

    begin
      debugger(*a, up_level: up_level, **kw)
      self
    rescue ArgumentError # for before 1.2.5
      debugger(*a, **kw)
      self
    end
  end

  alias b debugger if ENV['RUBY_DEBUG_B']
end

class Binding
  alias break debugger
  alias b debugger
end

# frozen_string_literal: true

require_relative 'console'

module DEBUGGER__
  #
  # Custom interface for easier associations
  #
  class TestUI_Console < UI_Console
    attr_accessor :queue, :test_block

    def quit _n
      SESSION.q_evt.close
      SESSION.tp_load_script.disable
      SESSION.tp_thread_begin.disable
    end

    def initialize
      @mutex = Mutex.new
      @assertion_cv = ConditionVariable.new
      @counter = 0
      @queue = Queue.new
    end

    def ask _prompt
      ''
    end

    def readline
      readline_body
    end

    def readline_body
      test_block&.call
      self.test_block = nil
      cmd = queue.pop
      if cmd.is_a?(Proc)
        cmd.call
        return nil
    end
      cmd
    end
  end
end

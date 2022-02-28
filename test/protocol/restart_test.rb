# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  
  class RestartTest < TestCase
    PROGRAM = <<~RUBY
      1| a = 1
    RUBY
    
    def test_restart
      run_protocol_scenario PROGRAM do
        req_terminate_debuggee
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__
  class WatchTest < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| a = 2
      2| a += 1
      3| a += 1
      4| d = 4
      5| a += 1
      6| e = 5
      7| f = 6
    RUBY

    def test_watch_matches_with_stopped_place
      run_protocol_scenario PROGRAM do
        req_next
        assert_watch_result({value: '2', type: 'Integer'}, 'a')
        req_next
        assert_watch_result({value: '3', type: 'Integer'}, 'a')
        req_next
        assert_watch_result({value: '4', type: 'Integer'}, 'a')
        req_terminate_debuggee
      end
    end
  end
end

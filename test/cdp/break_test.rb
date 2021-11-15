# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class BasicBreakTest < TestCase
    PROGRAM = <<~RUBY
      1| module Foo
      2|   class Bar
      3|     def self.a
      4|       "hello"
      5|     end
      6|   end
      7|   Bar.a
      8|   bar = Bar.new
      9| end
    RUBY

    def test_break_does_not_stop_anyware
      run_cdp_scenario PROGRAM do
        res1 = cdp_request 'Debugger.setBreakpointByUrl', condition: '', lineNumber: 7, url: "http://debuggee#{temp_file_path}"
        res2 = cdp_request 'Debugger.setBreakpointByUrl', condition: '', lineNumber: 5, url: "http://debuggee#{temp_file_path}"
        res3 = cdp_request 'Debugger.setBreakpointByUrl', condition: '', lineNumber: 3, url: "http://debuggee#{temp_file_path}"
        res4 = cdp_request 'Debugger.setBreakpointByUrl', condition: '', lineNumber: 10, url: "http://debuggee#{temp_file_path}"
        cdp_request 'Debugger.removeBreakpoint', breakpointId: res2.dig('result', 'breakpointId')
        cdp_request 'Debugger.removeBreakpoint', breakpointId: res3.dig('result', 'breakpointId')
        cdp_request 'Debugger.removeBreakpoint', breakpointId: res1.dig('result', 'breakpointId')
        cdp_request 'Debugger.removeBreakpoint', breakpointId: res4.dig('result', 'breakpointId')
        cdp_request 'Debugger.resume'
        assert_finish_cdp
      end
    end
  end
end

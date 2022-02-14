# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class BreakUnitTest1643981380 < TestCase
    PROGRAM = <<~RUBY
       1| module Foo
       2|    class Bar
       3|      def self.a
       4|        "hello"
       5|      end
       6|    end
       7|  puts :hoge
       8|    Bar.a
       9|    bar = Bar.new
      10|  end
    RUBY
    
    def test_break_works_correctly
      run_dap_scenario PROGRAM do
        dap_req command: "setBreakpoints",
                arguments: {
                  source: {
                    name: "target.rb",
                    path: temp_file_path,
                    sourceReference: nil
                  },
                  lines: [
                    8
                  ],
                  breakpoints: [
                    {
                      line: 8
                    }
                  ],
                  sourceModified: false
                }
        assert_dap_res command: "setBreakpoints",
                      success: true,
                      message: "Success",
                      body: {
                        breakpoints: [
                          {
                            verified: true
                          }
                        ]
                      }
        dap_req command: "continue",
                arguments: {
                  threadId: 1
                }
        assert_dap_res command: "continue",
                      success: true,
                      message: "Success",
                      body: {
                        allThreadsContinued: true
                      }
        dap_req command: "continue",
                arguments: {
                  threadId: 1
                }
        assert_dap_res command: "continue",
                      success: true,
                      message: "Success",
                      body: {
                        allThreadsContinued: true
                      }
      end
    end
  end
end

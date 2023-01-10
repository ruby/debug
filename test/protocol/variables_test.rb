# frozen_string_literal: true

require_relative "../support/protocol_test_case"

module DEBUGGER__
  class DAPVariablesTest < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| $a = 1
      2| $b = 2
      3| $c = 3
    RUBY

    def test_eval_evaluates_global_variables
      run_protocol_scenario PROGRAM, cdp: false do
        req_add_breakpoint 3
        req_continue

        globals = gather_variables(type: "globals")

        # User defined globals
        assert_includes(globals, { name: "$a", value: "1", type: "Integer" })
        assert_includes(globals, { name: "$b", value: "2", type: "Integer" })

        # Ruby defined globals
        assert_includes(globals, { name: "$VERBOSE", value: "false", type: "FalseClass" })
        assert_includes(globals, { name: "$stdout", value: "#<IO:<STDOUT>>", type: "IO" })

        req_terminate_debuggee
      end
    end
  end

  class CDPVariablesTest < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| $a = 1
      2| $b = 2
      3| $c = 3
    RUBY

    def test_eval_evaluates_global_variables
      run_protocol_scenario PROGRAM, dap: false do
        req_add_breakpoint 3
        req_continue

        globals = gather_variables(type: "global")

        # User defined globals
        assert_includes(globals, { name: "$a", value: "1", type: "Number" })
        assert_includes(globals, { name: "$b", value: "2", type: "Number" })

        # Ruby defined globals
        assert_includes(globals, { name: "$VERBOSE", value: "false", type: "Boolean" })
        assert_includes(globals, { name: "$stdout", value: "#<IO:<STDOUT>>", type: "Object" })

        req_terminate_debuggee
      end
    end
  end
end

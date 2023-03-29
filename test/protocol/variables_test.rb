# frozen_string_literal: true

require_relative "../support/protocol_test_case"

module DEBUGGER__
  class DAPGlobalVariablesTest < ProtocolTestCase
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
        assert_includes(globals, { name: "$a", value: "1", type: "Integer", variablesReference: 0 })
        assert_includes(globals, { name: "$b", value: "2", type: "Integer", variablesReference: 0 })

        # Ruby defined globals
        assert_includes(globals, { name: "$VERBOSE", value: "false", type: "FalseClass", variablesReference: 0 })
        assert_includes(globals, { name: "$stdout", value: "#<IO:<STDOUT>>", type: "IO", variablesReference: 0 })

        req_terminate_debuggee
      end
    end
  end

  class CDPGlobalVariablesTest < ProtocolTestCase
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

  class DAPInstanceVariableTest < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| @a = 1
      2| @c = 3
      3| @b = 2
      4| __LINE__
    RUBY

    def test_ordering_instance_variables
      run_protocol_scenario PROGRAM, cdp: false do
        req_add_breakpoint 4
        req_continue

        locals = gather_variables

        variables_reference = locals.find { |local| local[:name] == "%self" }[:variablesReference]
        res = send_dap_request 'variables', variablesReference: variables_reference

        instance_vars = res.dig(:body, :variables)
        assert_equal instance_vars.map { |var| var[:name] }, ["#class", "@a", "@b", "@c"]

        req_terminate_debuggee
      end
    end
  end

  class DAPOverwrittenNameMethod < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| class Foo
      2|   def self.name(value) end
      3| end
      4| f = Foo.new
      5| __LINE__
    RUBY

    def test_overwritten_name_method
      run_protocol_scenario PROGRAM, cdp: false do
        req_add_breakpoint 5
        req_continue

        locals = gather_variables

        variable_info = locals.find { |local| local[:name] == "f" }

        assert_match /#<Foo:.*>/, variable_info[:value]
        assert_match /<Error: wrong number of arguments \(given 0, expected 1\) /, variable_info[:type]

        req_terminate_debuggee
      end
    end
  end

  class DAPOverwrittenToSMethod < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| class Foo
      2|   def self.name
      3|     nil
      4|   end
      5|   def self.to_s(value) end
      6| end
      7| f = Foo.new
      8| __LINE__
    RUBY

    def test_overwritten_to_s_method
      run_protocol_scenario PROGRAM, cdp: false do
        req_add_breakpoint 8
        req_continue

        locals = gather_variables

        variable_info = locals.find { |local| local[:name] == "f" }
        assert_match /#<Foo:.*>/, variable_info[:value]
        assert_match /<Error: wrong number of arguments \(given 0, expected 1\) /, variable_info[:type]

        req_terminate_debuggee
      end
    end
  end

  class DAPOverwrittenClassMethod < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| class Foo
      2|   def self.class(value) end
      3| end
      4| f = Foo.new
      5| __LINE__
    RUBY

    def test_overwritten_class_method
      run_protocol_scenario PROGRAM, cdp: false do
        req_add_breakpoint 5
        req_continue

        locals = gather_variables

        variable_info = locals.find { |local| local[:name] == "f" }
        assert_match /#<Foo:.*>/, variable_info[:value]
        assert_equal "Foo", variable_info[:type]

        req_terminate_debuggee
      end
    end
  end
end

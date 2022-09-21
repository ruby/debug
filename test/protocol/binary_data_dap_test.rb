# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__
  class BinaryDataDAPTest < ProtocolTestCase
    def test_binary_data_gets_encoded
      program = <<~RUBY
        1| class PassthroughInspect
        2|   def initialize(data)
        3|     @data = data
        4|   end
        5|
        6|   def inspect
        7|     @data
        8|   end
        9| end
        10|
        11| with_binary_data = PassthroughInspect.new([8, 200, 1].pack('CCC'))
        12| with_binary_data
      RUBY
      run_protocol_scenario(program, cdp: false) do
        req_add_breakpoint 12
        req_continue
        assert_locals_result(
          [
            { name: '%self', value: 'main', type: 'Object' },
            { name: 'with_binary_data', value: /\[Invalid encoding\] /, type: 'PassthroughInspect' }
          ]
        )
        req_terminate_debuggee
      end
    end

    def test_frozen_strings_are_supported
      # When `inspect` fails, `DEBUGGER__.safe_inspect` returns a frozen error message
      # Just returning a frozen string wouldn't work, as `DEBUGGER__.safe_inspect` constructs
      # the return value with a buffer.
      program = <<~RUBY
        1| class Uninspectable
        2|   def inspect; raise 'error'; end
        3| end
        4| broken_inspect = Uninspectable.new
        5| broken_inspect
      RUBY
      run_protocol_scenario(program, cdp: false) do
        req_add_breakpoint 5
        req_continue
        assert_locals_result(
          [
            { name: '%self', value: 'main', type: 'Object' },
            { name: 'broken_inspect', value: /#inspect raises/, type: 'Uninspectable' }
          ]
        )
        req_terminate_debuggee
      end
    end
  end
end

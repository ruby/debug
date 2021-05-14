# frozen_string_literal: true

module DEBUGGER__
  #
  # Misc tools for the test suite
  #
  module TestUtils
    #
    # Adds commands to the input queue, so they will be later retrieved by
    # Processor, i.e., it emulates user's input.
    #
    # If a command is a Proc object, it will be executed before being retrieved
    # by Processor. May be handy when you need build a command depending on the
    # current context.
    #
    # @example
    #
    #   enter "b 12", "cont"
    #   enter "b 12", ->{ "disable #{breakpoint.id}" }, "cont"
    #
    def enter(messages)
      ui_console.queue.push(messages)
    end

    def assertion(expected)
      ui_console.queue.push Proc.new {
        actual = DEBUGGER__::SESSION.th_clients[Thread.main].target_frames[0].location.lineno
        assert_equal expected, actual
      }
    end

    #
    # Runs the code block passed as a string.
    #
    # The string is copied to a new file and then that file is run. This is
    # done, instead of using `instance_eval` or similar techniques, because
    # it's useful to load a real file in order to make assertions on backtraces
    # or file names.
    #
    # @param program String containing Ruby code to be run. This string could
    # be any valid Ruby code, but in order to avoid redefinition warnings in
    # the test suite, it should define at most one class inside the DEBUGGER__
    # namespace. The name of this class is defined by the +example_class+
    # method.
    #
    # @param &block Optional proc which will be executed when Processor
    # extracts all the commands from the input queue. You can use that for
    # making assertions on the current test. If you specified the block and it
    # was never executed, the test will fail.
    #
    # @example
    #
    #   enter "next"
    #   prog <<-RUBY
    #     puts "hello"
    #   RUBY
    #
    #   debug_code(prog) { assert_equal 3, frame.line }
    #
    def debug_code(program, &block)
      ui_console.test_block = block
      debug_in_temp_file(program)
    end

    #
    # Writes a string containing Ruby code to a file and then debugs that file.
    #
    # @param program [String] Ruby code to be debugged
    #
    def debug_in_temp_file(program)
      example_file.write(program)
      example_file.close

      load(example_path)
    end

    def ui_console
      Session.ui_console
    end

    def current_frame
      ThreadClient.current.current_frame
    end

    #
    # Remove +const+ from +klass+ without a warning
    #
    def force_remove_const(kclass, const)
      kclass.send(:remove_const, const) if kclass.const_defined?(const)
    end

    #
    # Strips line numbers from a here doc containing ruby code.
    #
    # @param str_with_ruby_code A here doc containing lines of ruby code, each
    # one labeled with a line number
    #
    # @example
    #
    #   strip_line_numbers <<-EOF
    #     1:  puts "hello"
    #     2:  puts "bye"
    #   EOF
    #
    #   returns
    #
    #   puts "hello"
    #   puts "bye"
    #
    def strip_line_numbers(str_with_ruby_code)
      str_with_ruby_code.gsub(/  *\d+: ? ?/, '')
    end
  end
end

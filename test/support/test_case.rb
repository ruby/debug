# frozen_string_literal: true

require 'test/unit'
require 'tempfile'
require 'securerandom'

require_relative 'utils'
require_relative 'dap_utils'
require_relative 'assertions'

module DEBUGGER__
  class TestCase < Test::Unit::TestCase
    include TestUtils
    include DAP_TestUtils
    include AssertionHelpers

    def setup
      @temp_file = nil
    end

    def teardown
      remove_temp_file
    end

    def temp_file_path
      @temp_file.path
    end

    def remove_temp_file
      File.unlink(@temp_file) if @temp_file
      @temp_file = nil
    end

    def write_temp_file(program)
      @temp_file = Tempfile.create(%w[debug- .rb])
      @temp_file.write(program)
      @temp_file.close
    end

    def with_extra_tempfile(*additional_words)
      name = SecureRandom.hex(5) + additional_words.join

      t = Tempfile.create([name, '.rb']).tap do |f|
        f.write(extra_file)
        f.close
      end
      yield t
    ensure
      File.unlink t if t
    end

    LINE_NUMBER_REGEX = /^\s*\d+\| ?/

    def strip_line_num(str)
      str.gsub(LINE_NUMBER_REGEX, '')
    end

    def check_line_num!(program)
      unless program.match?(LINE_NUMBER_REGEX)
        new_program = program_with_line_numbers(program)
        raise "line numbers are required in test script. please update the script with:\n\n#{new_program}"
      end
    end

    def program_with_line_numbers(program)
      lines = program.split("\n")
      lines_with_number = lines.map.with_index do |line, i|
        "#{'%4d' % (i+1)}| #{line}"
      end

      lines_with_number.join("\n")
    end
  end

  # When constant variables are referred from modules, they have to be defined outside the class.
  INITIALIZE_DAP_MSGS = [
    {
      seq: 1,
      command: "initialize",
      arguments: {
        clientID: "vscode",
        clientName: "Visual Studio Code",
        adapterID: "rdbg",
        pathFormat: "path",
        linesStartAt1: true,
        columnsStartAt1: true,
        supportsVariableType: true,
        supportsVariablePaging: true,
        supportsRunInTerminalRequest: true,
        locale: "en-us",
        supportsProgressReporting: true,
        supportsInvalidatedEvent: true,
        supportsMemoryReferences: true
      },
      type: "request"
    },
    {
      seq: 2,
      command: "attach",
      arguments: {
        type: "rdbg",
        name: "Attach with rdbg",
        request: "attach",
        rdbgPath: File.expand_path('../../exe/rdbg', __dir__),
        debugPort: "/var/folders/kv/w1k6nh1x5fl7vx47b2pd005w0000gn/T/ruby-debug-sock-501/ruby-debug-naotto-8845",
        autoAttach: true,
        __sessionId: "141d9c79-3669-43ec-ac1f-e62598c5a65a"
      },
      type: "request"
    },
    {
      seq: 3,
      command: "setFunctionBreakpoints",
      arguments: {
        breakpoints: [

        ]
      },
      type: "request"
    },
    {
      seq: 4,
      command: "setExceptionBreakpoints",
      arguments: {
        filters: [

        ],
        filterOptions: [
          {
            filterId: "RuntimeError"
          }
        ]
      },
      type: "request"
    },
    {
      seq: 5,
      command: "configurationDone",
      type: "request"
    }
  ]
end

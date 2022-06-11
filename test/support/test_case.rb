# frozen_string_literal: true

require 'test/unit'
require 'tempfile'
require 'securerandom'

require_relative 'utils'
require_relative 'dap_utils'
require_relative 'cdp_utils'
require_relative 'protocol_utils'
require_relative 'assertions'

module DEBUGGER__
  class TestCase < Test::Unit::TestCase
    include TestUtils
    include DAP_TestUtils
    include CDP_TestUtils
    include Protocol_TestUtils
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

    def create_protocol_message fail_msg
      all_protocol_msg = <<~DEBUGGER_MSG.chomp
        -------------------------
        | All Protocol Messages |
        -------------------------

        #{@backlog.join("\n")}
      DEBUGGER_MSG

      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        pattern = /(D|V)(<|>)(D|V)\s/
      when 'chrome'
        pattern = /(D|C)(<|>)(D|C)\s/
      end

      last_msg = @backlog.last(3).map{|log|
        json = log.sub(pattern, '')
        JSON.pretty_generate(JSON.parse json)
      }.join("\n")

      last_protocol_msg = <<~DEBUGGER_MSG.chomp
        --------------------------
        | Last Protocol Messages |
        --------------------------

        #{last_msg}
      DEBUGGER_MSG

      debuggee_msg =
          <<~DEBUGGEE_MSG.chomp
            --------------------
            | Debuggee Session |
            --------------------

            > #{@remote_info.debuggee_backlog.join('> ')}
          DEBUGGEE_MSG

      failure_msg = <<~FAILURE_MSG.chomp
        -------------------
        | Failure Message |
        -------------------

        #{fail_msg}
      FAILURE_MSG

      <<~MSG.chomp
        #{all_protocol_msg}

        #{last_protocol_msg}

        #{debuggee_msg}

        #{failure_msg}
      MSG
    end
  end

  class WebSocketClient
    class Frame
      attr_reader :binary

      def initialize
        @binary = ''.b
      end

      def << obj
        case obj
        when String
          @binary << obj.b
        when Enumerable
          obj.each{|e| self << e}
        end
      end

      def char bytes
        @binary << bytes
      end

      def ulonglong bytes
        @binary << [bytes].pack('Q>')
      end

      def uint16 bytes
        @binary << [bytes].pack('n*')
      end
    end

    def initialize s
      @sock = s
    end

    def handshake port, path
      key = SecureRandom.hex(11)
      @sock.print "GET #{path} HTTP/1.1\r\nHost: 127.0.0.1:#{port}\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: #{key}==\r\n\r\n"
      res = nil
      loop do
        res = @sock.readpartial 4092
        break unless res.match?(/out|input/)
      end

      if res.match(/^Sec-WebSocket-Accept: (.*)\r\n/)
        correct_key = Base64.strict_encode64 Digest::SHA1.digest "#{key}==258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        raise "The Sec-WebSocket-Accept value: #{$1} is not valid" unless $1 == correct_key
      else
        raise "Unknown response: #{res}"
      end
    end

    def send msg
      msg = JSON.generate(msg)
      frame = Frame.new
      fin = 0b10000000
      opcode = 0b00000001
      frame.char fin + opcode

      mask = 0b10000000 # A client must mask all frames in a WebSocket Protocol.
      bytesize = msg.bytesize
      if bytesize < 126
        payload_len = bytesize
        frame.char mask + payload_len
      elsif bytesize < 2 ** 16
        payload_len = 0b01111110
        frame.char mask + payload_len
        frame.uint16 bytesize
      elsif bytesize < 2 ** 64
        payload_len = 0b01111111
        frame.char mask + payload_len
        frame.ulonglong bytesize
      else
        raise 'Bytesize is too big.'
      end

      masking_key = 4.times.map{
        key = rand(1..255)
        frame.char key
        key
      }
      msg.bytes.each_with_index do |b, i|
        frame.char(b ^ masking_key[i % 4])
      end

      @sock.print frame.binary
    end

    def extract_data
      first_group = @sock.getbyte
      fin = first_group
      return nil if fin.nil?
      raise 'Unsupported' if fin & 0b10000000 != 128
      opcode = first_group & 0b00001111
      raise "Unsupported: #{opcode}" unless opcode == 1

      second_group = @sock.getbyte
      mask = second_group & 0b10000000 == 128
      raise 'The server must not mask any frames' if mask
      payload_len = second_group & 0b01111111
      # TODO: Support other payload_lengths
      if payload_len == 126
        payload_len = @sock.read(2).unpack('n*')[0]
      end

      JSON.parse @sock.read(payload_len), symbolize_names: true
    end

    def send_close_connection
      frame = []
      fin = 0b10000000
      opcode = 0b00001000
      frame << fin + opcode

      @sock.print frame.pack 'c*'
    end

    def close
      @sock.close
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

  INITIALIZE_CDP_MSGS = [
    {
      id: 1,
      method: "Runtime.enable",
      params: {
      }
    },
    {
      id: 2,
      method: "Debugger.enable",
      params: {
        maxScriptsCacheSize: 10000000
      }
    },
    {
      id: 3,
      method: "Debugger.setPauseOnExceptions",
      params: {
        state: "none"
      }
    },
    {
      id: 4,
      method: "Debugger.setAsyncCallStackDepth",
      params: {
        maxDepth: 32
      }
    },
    {
      id: 5,
      method: "Profiler.enable",
      params: {
      }
    },
    {
      id: 6,
      method: "Debugger.setBlackboxPatterns",
      params: {
        patterns: [

        ]
      }
    },
    {
      id: 7,
      method: "Runtime.runIfWaitingForDebugger",
      params: {
      }
    }
  ]

  class ResponsePattern
    def initialize
      @result = []
      @keys = []
    end

    def parse objs
      objs.each{|k, v|
        parse_ k, v
        @keys.pop
      }
      @result
    end

    def parse_ k, v
      @keys << k
      case v
      when Array
        v.each.with_index{|v, i|
          parse_ i, v
          @keys.pop
        }
      when Hash
        v.each{|k, v|
          parse_ k, v
          @keys.pop
        }
      else
        @result << [@keys.dup, v]
      end
    end
  end
end

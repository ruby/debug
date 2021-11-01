# frozen_string_literal: true

require_relative 'support/test_case'
require_relative '../lib/debug/session'
require 'socket'
require 'digest/sha1'
require 'base64'
require 'securerandom'

module DEBUGGER__
  class CDP_Test < TestCase
    SHOW_PROTOCOL = false
    class WebSocketClient
      def initialize s
        @sock = s
      end

      def handshake port, path
        key = SecureRandom.hex(11)
        @sock.print "GET #{path} HTTP/1.1\r\nHost: 127.0.0.1:#{port}\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: #{key}==\r\n\r\n"
        res = @sock.readpartial 4092
        $stderr.puts '[>]' + res if SHOW_PROTOCOL

        if res.match /^Sec-WebSocket-Accept: (.*)\r\n/
          correct_key = Base64.strict_encode64 Digest::SHA1.digest "#{key}==258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
          raise "The Sec-WebSocket-Accept value: #{$1} is not valid" unless $1 == correct_key
        else
          raise "Unknown response: #{res}"
        end
      end

      def send **msg
        msg = JSON.generate(msg)
        frame = []
        fin = 0b10000000
        opcode = 0b00000001
        frame << fin + opcode

        mask = 0b10000000 # A client must mask all frames in a WebSocket Protocol.
        bytesize = msg.bytesize
        if bytesize < 126
          payload_len = bytesize
        elsif bytesize < 2 ** 16
          payload_len = 0b01111110
          ex_payload_len = [bytesize].pack('n*').bytes
        else
          payload_len = 0b01111111
          ex_payload_len = [bytesize].pack('Q>').bytes
        end

        frame << mask + payload_len
        frame.push *ex_payload_len if ex_payload_len

        frame.push *masking_key = 4.times.map{rand(1..255)}
        masked = []
        msg.bytes.each_with_index do |b, i|
          masked << (b ^ masking_key[i % 4])
        end

        frame.push *masked
        @sock.print frame.pack 'c*'
      end

      def extract_data
        first_group = @sock.getbyte
        fin = first_group & 0b10000000 != 128
        raise 'Unsupported' if fin
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

        data = JSON.parse @sock.read payload_len
        $stderr.puts '[>]' + data.inspect if SHOW_PROTOCOL
        data
      end
    end

    def test_connect
      write_temp_file <<~RUBY
        module Foo
          class Bar
            def self.a
              "hello"
            end
          end
          Bar.a
          bar = Bar.new
        end
      RUBY
      pid = spawn("#{RDBG_EXECUTABLE} --open=chrome --port=#{TCPIP_PORT} -- #{temp_file_path}")
      begin
        s = Socket.tcp '127.0.0.1', TCPIP_PORT
      rescue Errno::ECONNREFUSED
        sleep 0.5
        retry
      end
      ws_client = WebSocketClient.new(s)
      ws_client.handshake 9222, '/'
      ws_client.send id: 1, method: 'Page.getResourceTree'
      res = ws_client.extract_data
      assert_equal res.dig('result', 'frameTree', 'frame', 'url'), 'http://debuggee/'
      res = ws_client.extract_data
      assert_equal res.dig('method'), 'Debugger.scriptParsed'
      assert_equal res.dig('params', 'url'), "http://debuggee#{temp_file_path}"
      res = ws_client.extract_data
      assert_equal res.dig('method'), 'Runtime.executionContextCreated'
      ws_client.send id: 2, method: 'Debugger.getScriptSource',
                      params: {scriptId: temp_file_path}
      res = ws_client.extract_data
      assert_equal res.dig('result', 'scriptSource'), File.read(temp_file_path)
      kill_safely pid, nil
    end
  end
end

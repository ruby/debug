require 'socket'
require 'rbconfig'
require 'json'
require 'pp'

require_relative '../config'
require_relative '../server_cdp'
require_relative '../session'

module DEBUGGER__
  module ChromePrettyPrint
    class CDPServer
      include UI_CDP
      include ThreadClient_CDP
      HOST = '127.0.0.1'

      def initialize queue
        @obj_map = {}
        @queue = queue
        activate
      end

      def activate
        accept do |sock|
          th = Thread.new(sock) {
            @ws_server = WebSocketServer.new sock
            @ws_server.handshake
            process_req
          }
          ::DEBUGGER__.const_set(:THREAD, th)
        end
      end

      def accept
        TCPServer.open(HOST, 0){|serv|
          addr = serv.local_address.inspect_sockaddr
          UI_CDP.setup_chrome addr
          sock = serv.accept
          yield sock
        }
      end

      METHOD_NOT_FOUND = -32601

      def process_req
        loop do
          req = @ws_server.extract_data

          case method = req['method']
          when 'Runtime.enable'
            send_response req
            @th = Thread.new do
              while msg = @queue.pop
                send_event 'Runtime.consoleAPICalled',
                          type: 'log',
                          args: [evaluate_result(msg)],
                          executionContextId: 1,
                          timestamp: Time.now.to_f
              end
            end
          when 'Runtime.getProperties'
            o_id = req.dig('params', 'objectId')
            result, prop = analyze_obj o_id

            send_response req, result: result, internalProperties: prop
          else
            send_fail_response req,
                              code: METHOD_NOT_FOUND,
                              message: "'#{method}' wasn't found"
          end
        end
      ensure
        @th.kill
      end
    end

    class ChromePP
      def initialize
        q = Queue.new
        ::DEBUGGER__.const_set(:QUEUE, q)
        CDPServer.new q
      end
    end

    def self.start
      ChromePP.new
    end
  end
end

module ExtendPP
  def pp(*args)
    args.each{|arg|
      DEBUGGER__::QUEUE << arg
    }
    super(*args)
  end
end

module Kernel
  prepend ExtendPP
end

DEBUGGER__::ChromePrettyPrint.start

at_exit{
  DEBUGGER__::THREAD.join
}

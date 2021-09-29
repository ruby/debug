# frozen_string_literal: true

require 'socket'
require_relative 'config'
require_relative 'version'

module DEBUGGER__
  class UI_ServerBase < UI_Base
    def initialize
      @sock = @sock_for_fork = nil
      @accept_m = Mutex.new
      @accept_cv = ConditionVariable.new
      @client_addr = nil
      @q_msg = nil
      @q_ans = nil
      @unsent_messages = []
      @width = 80
    end

    class Terminate < StandardError
    end

    def deactivate
      @reader_thread.raise Terminate
    end

    def accept
      if @sock_for_fork
        begin
          yield @sock_for_fork, already_connected: true
        ensure
          @sock_for_fork.close
          @sock_for_fork = nil
        end
      end
    end

    def activate session, on_fork: false
      @reader_thread = Thread.new do
        # An error on this thread should break the system.
        Thread.current.abort_on_exception = true

        accept do |server, already_connected: false|
          DEBUGGER__.warn "Connected."

          @accept_m.synchronize{
            @sock = server
            greeting

            @accept_cv.signal

            # flush unsent messages
            @unsent_messages.each{|m|
              @sock.puts m
            }
            @unsent_messages.clear

            @q_msg = Queue.new
            @q_ans = Queue.new
          } unless already_connected

          setup_interrupt do
            pause unless already_connected
            process
          end

        rescue Terminate
          raise # should catch at outer scope
        rescue => e
          DEBUGGER__.warn "ReaderThreadError: #{e}"
        ensure
          DEBUGGER__.warn "Disconnected."
          @sock = nil
          @q_msg.close
          @q_msg = nil
          @q_ans.close
          @q_ans = nil
        end # accept

      rescue Terminate
        # ignore
      end
    end

    def greeting
      case g = @sock.gets
      when /^version:\s+(.+)\s+width: (\d+) cookie:\s+(.*)$/
        v, w, c = $1, $2, $3
        # TODO: protocol version
        if v != VERSION
          raise "Incompatible version (#{VERSION} client:#{$1})"
        end

        cookie = CONFIG[:cookie]
        if cookie && cookie != c
          raise "Cookie mismatch (#{$2.inspect} was sent)"
        end

        @width = w.to_i

      when /^Content-Length: (\d+)/
        require_relative 'server_dap'

        raise unless @sock.read(2) == "\r\n"
        self.extend(UI_DAP)
        dap_setup @sock.read($1.to_i)
      else
        raise "Greeting message error: #{g}"
      end
    end

    def process
      while line = @sock.gets
        case line
        when /\Apause/
          pause
        when /\Acommand ?(.+)/
          @q_msg << $1
        when /\Aanswer (.*)/
          @q_ans << $1
        when /\Awidth (.+)/
          @width = $1.to_i
        else
          STDERR.puts "unsupported: #{line}"
          exit!
        end
      end
    end

    def remote?
      true
    end

    def width
      @width
    end

    def setup_interrupt
      prev_handler = trap(:SIGURG) do
        # $stderr.puts "trapped SIGINT"
        ThreadClient.current.on_trap :SIGURG

        case prev_handler
        when Proc
          prev_handler.call
        else
          # ignore
        end
      end

      if prev_handler != "SYSTEM_DEFAULT"
        DEBUGGER__.warn "SIGURG handler is overriddend by the debugger."
      end
      yield
    ensure
      trap(:SIGURG, prev_handler)
    end

    attr_reader :reader_thread

    class NoRemoteError < Exception; end

    def sock skip: false
      if s = @sock         # already connection
        # ok
      elsif skip == true   # skip process
        no_sock = true
        r = @accept_m.synchronize do
          if @sock
            no_sock = false
          else
            yield nil
          end
        end
        return r if no_sock
      else                 # wait for connection
        until s = @sock
          @accept_m.synchronize{
            unless @sock
              DEBUGGER__.warn "wait for debugger connection..."
              @accept_cv.wait(@accept_m)
            end
          }
        end
      end

      yield s
    rescue Errno::EPIPE
      # ignore
    end

    def ask prompt
      sock do |s|
        s.puts "ask #{prompt}"
        @q_ans.pop
      end
    end

    def puts str = nil
      case str
      when Array
        enum = str.each
      when String
        enum = str.each_line
      when nil
        enum = [''].each
      end

      sock skip: true do |s|
        enum.each do |line|
          msg = "out #{line.chomp}"
          if s
            s.puts msg
          else
            @unsent_messages << msg
          end
        end
      end
    end

    def readline prompt
      input = (sock do |s|
        s.puts "input"
        sleep 0.01 until @q_msg

        @q_msg.pop
      end || 'continue')

      if input.is_a?(String)
        input.strip
      else
        input
      end
    end

    def pause
      # $stderr.puts "DEBUG: pause request"
      Process.kill(:SIGURG, Process.pid)
    end

    def quit n
      # ignore n
      sock do |s|
        s.puts "quit"
      end
    end
  end

  class UI_TcpServer < UI_ServerBase
    def initialize host: nil, port: nil
      @host = host || CONFIG[:host] || '127.0.0.1'
      @port = port || begin
        port_str = CONFIG[:port] || raise("Specify listening port by RUBY_DEBUG_PORT environment variable.")
        if /\A\d+\z/ !~ port_str
          raise "Specify digits for port number"
        else
          port_str.to_i
        end
      end

      super()
    end

    def accept
      retry_cnt = 0
      super # for fork

      begin
        Socket.tcp_server_sockets @host, @port do |socks|
          ::DEBUGGER__.warn "Debugger can attach via TCP/IP (#{socks.map{|e| e.local_address.inspect}})"
          Socket.accept_loop(socks) do |sock, client|
            @client_addr = client
            yield @sock_for_fork = sock
          end
        end
      rescue Errno::EADDRINUSE
        if retry_cnt < 10
          retry_cnt += 1
          sleep 0.1
          retry
        else
          raise
        end
      rescue Terminate
        # OK
      rescue => e
        $stderr.puts e.inspect, e.message
        pp e.backtrace
        exit
      end
    ensure
      @sock_for_fork = nil
    end
  end

  class UI_UnixDomainServer < UI_ServerBase
    attr_reader :sock_path

    def initialize sock_dir: nil, sock_path: nil
      @sock_path = sock_path
      @sock_dir = sock_dir || DEBUGGER__.unix_domain_socket_dir
      @sock_for_fork = nil

      super()
    end

    def accept
      super # for fork

      case
      when @sock_path
      when sp = CONFIG[:sock_path]
        @sock_path = sp
      else
        @sock_path = DEBUGGER__.create_unix_domain_socket_name(@sock_dir)
      end

      ::DEBUGGER__.warn "Debugger can attach via UNIX domain socket (#{@sock_path})"
      Socket.unix_server_loop @sock_path do |sock, client|
        @sock_for_fork = sock
        @client_addr = client

        yield sock
      ensure
        sock.close
        @sock_for_fork = nil
      end
    end
  end
end

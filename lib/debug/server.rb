require 'socket'
require_relative 'session'
require_relative 'config'

module DEBUGGER__
  class UI_ServerBase
    def initialize
      @sock = nil
      @accept_m = Mutex.new
      @accept_cv = ConditionVariable.new
      @client_addr = nil
      @q_msg = Queue.new
      @q_ans = Queue.new
      @unsent_messages = []

      @reader_thread = Thread.new do
        accept do |server|
          DEBUGGER__.message "Connected."

          @accept_m.synchronize{
            @sock = server
            @accept_cv.signal

            # flush unsent messages
            @unsent_messages.each{|m|
              @sock.puts m
            }
            @unsent_messages.clear
          }
          @q_msg = Queue.new
          @q_ans = Queue.new

          setup_interrupt do
            pause

            while line = @sock.gets
              case line
              when /\Apause/
                pause
              when /\Acommand ?(.+)/
                @q_msg << $1
              when /\Aanswer (.*)/
                @q_ans << $1
              else
                STDERR.puts "unsupported: #{line}"
                exit!
              end
            end
          end
        ensure
          DEBUGGER__.message "Disconnected."
          @sock = nil
          @q_msg.close
          @q_ans.close
        end
      end
    end

    def remote?
      true
    end

    def setup_interrupt
      prev_handler = trap(:SIGINT) do
        # $stderr.puts "trapped SIGINT"
        ThreadClient.current.on_trap :SIGINT

        case prev_handler
        when Proc
          prev_handler.call
        else
          # ignore
        end
      end

      yield
    ensure
      trap(:SIGINT, prev_handler)
    end

    def accept
      raise "NOT IMPLEMENTED ERROR"
    end

    attr_reader :reader_thread

    class NoRemoteError < Exception; end

    def sock skip: false
      if s = @sock         # already connection
        # ok
      elsif skip == true   # skip process
        return yield nil
      else                 # wait for connection
        until s = @sock
          @accept_m.synchronize{
            unless @sock
              DEBUGGER__.message "wait for debuger connection..."
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

    def readline
      (sock do |s|
        s.puts "input"
        @q_msg.pop
      end || 'continue').strip
    end

    def pause
      # $stderr.puts "DEBUG: pause request"
      Process.kill(:SIGINT, Process.pid)
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
      @host = host || ::DEBUGGER__::CONFIG[:host] || 'localhost'
      @port = port || begin
        port_str = ::DEBUGGER__::CONFIG[:port] || raise("Specify listening port by RUBY_DEBUG_PORT environment variable.")
        if /\A\d+\z/ !~ port_str
          raise "Specify digits for port number"
        else
          port_str.to_i
        end
      end

      super()
    end

    def accept
      Socket.tcp_server_sockets @host, @port do |socks|
        ::DEBUGGER__.message "Debugger can attach via TCP/IP (#{socks.map{|e| e.local_address.inspect}})"
        Socket.accept_loop(socks) do |sock, client|
          @client_addr = client
          yield sock
        end
      end
    rescue => e
      $stderr.puts e.message
      pp e.backtrace
      exit
    end
  end

  class UI_UnixDomainServer < UI_ServerBase
    def initialize sock_dir: nil
      @sock_dir = sock_dir || DEBUGGER__.unix_domain_socket_dir

      super()
    end

    def accept
      if f = DEBUGGER__::CONFIG[:sock_path]
        @file = f
      else
        @file = DEBUGGER__.create_unix_domain_socket_name(@sock_dir)
      end

      ::DEBUGGER__.message "Debugger can attach via UNIX domain socket (#{@file})"
      Socket.unix_server_loop @file do |sock, client|
        @client_addr = client
        yield sock
      end
    end
  end

  def self.open host: nil, port: ::DEBUGGER__::CONFIG[:port], sock_dir: nil
    if port
      open_tcp host: host, port: port
    else
      open_unix sock_dir: sock_dir
    end
  end

  def self.open_tcp(host: nil, port:)
    initialize_session UI_TcpServer.new(host: host, port: port)
  end

  def self.open_unix sock_dir: nil
    initialize_session UI_UnixDomainServer.new(sock_dir: sock_dir)
  end

  def self.message msg
    $stderr.puts "DEBUGGER: #{msg}"
  end
end

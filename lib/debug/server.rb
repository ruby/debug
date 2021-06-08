require 'socket'
require_relative 'session'
require_relative 'config'
require_relative 'version'

module DEBUGGER__
  class UI_ServerBase < UI_Base
    def initialize
      @sock = nil
      @accept_m = Mutex.new
      @accept_cv = ConditionVariable.new
      @client_addr = nil
      @q_msg = Queue.new
      @q_ans = Queue.new
      @unsent_messages = []
      @width = 80

      @reader_thread = Thread.new do
        # An error on this thread should break the system.
        Thread.current.abort_on_exception = true

        accept do |server|
          DEBUGGER__.message "Connected."

          @accept_m.synchronize{
            @sock = server
            greeting

            @accept_cv.signal

            # flush unsent messages
            @unsent_messages.each{|m|
              @sock.puts m
            }
            @unsent_messages.clear
          }

          process
        end
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
      else
        raise "Greeting message error: #{g}"
      end
    end

    def process
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
          when /\Awidth (.+)/
            @width = $1.to_i
          else
            STDERR.puts "unsupported: #{line}"
            exit!
          end
        end
      end
    rescue => e
      DEBUGGER__.message "Error: #{e}"
    ensure
      DEBUGGER__.message "Disconnected."
      @sock = nil
      @q_msg.close
      @q_ans.close
    end

    def remote?
      true
    end

    def width
      @width
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
      @host = host || ::DEBUGGER__::CONFIG[:host] || '127.0.0.1'
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
    def initialize sock_dir: nil, sock_path: nil
      @sock_path = sock_path
      @sock_dir = sock_dir || DEBUGGER__.unix_domain_socket_dir

      super()
    end

    def accept
      case
      when @sock_path
      when sp = ::DEBUGGER__::CONFIG[:sock_path]
        @sock_path = sp
      else
        @sock_path = DEBUGGER__.create_unix_domain_socket_name(@sock_dir)
      end

      ::DEBUGGER__.message "Debugger can attach via UNIX domain socket (#{@sock_path})"
      Socket.unix_server_loop @sock_path do |sock, client|
        @client_addr = client
        yield sock
      ensure
        sock.close
      end
    end
  end

  def self.message msg
    $stderr.puts "DEBUGGER: #{msg}"
  end
end

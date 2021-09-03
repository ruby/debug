# frozen_string_literal: true

require 'socket'
require 'io/console/size'

require_relative 'config'
require_relative 'version'
require_relative 'console'

# $VERBOSE = true

module DEBUGGER__
  class CommandLineOptionError < Exception; end

  class Client
    def initialize argv
      return util(argv) if String === argv

      @console = Console.new

      case argv.size
      when 0
        connect_unix
      when 1
        case arg = argv.shift
        when /-h/, /--help/
          help
          exit
        when /\A\d+\z/
          connect_tcp nil, arg.to_i
        else
          connect_unix arg
        end
      when 2
        connect_tcp argv[0], argv[1]
      else
        raise CommandLineOptionError
      end

      @width = IO.console_size[1]
      @width = 80 if @width == 0
      @width_changed = false

      send "version: #{VERSION} width: #{@width} cookie: #{CONFIG[:cookie]}"
    end

    def readline
      @console.readline "(rdbg:remote) "
    end

    def util name
      case name
      when 'gen-sockpath'
        puts DEBUGGER__.create_unix_domain_socket_name
      when 'list-socks'
        cleanup_unix_domain_sockets
        puts list_connections
      else
        raise "Unknown utility: #{name}"
      end
    end

    def cleanup_unix_domain_sockets
      Dir.glob(DEBUGGER__.create_unix_domain_socket_name_prefix + '*') do |file|
        if /(\d+)$/ =~ file
          begin
            Process.kill(0, $1.to_i)
          rescue Errno::ESRCH
            File.unlink(file)
          end
        end
      end
    end

    def list_connections
      Dir.glob(DEBUGGER__.create_unix_domain_socket_name_prefix + '*')
    end

    def connect_unix name = nil
      if name
        if File.exist? name
          @s = Socket.unix(name)
        else
          @s = Socket.unix(File.join(DEBUGGER__.unix_domain_socket_dir, name))
        end
      else
        cleanup_unix_domain_sockets
        files = list_connections
        case files.size
        when 0
          $stderr.puts "No debug session is available."
          exit
        when 1
          @s = Socket.unix(files.first)
        else
          $stderr.puts "Please select a debug session:"
          files.each{|f|
            $stderr.puts "  #{File.basename(f)}"
          }
          exit
        end
      end
    end

    def connect_tcp host, port
      @s = Socket.tcp(host, port)
    end

    def send msg
      p send: msg if $VERBOSE
      @s.puts msg
    end

    def connect
      trap(:SIGINT){
        send "pause"
      }
      trap(:SIGWINCH){
        @width = IO.console_size[1]
        @width_changed = true
      }

      while line = @s.gets
        p recv: line if $VERBOSE
        case line
        when /^out (.*)/
          puts "#{$1}"
        when /^input/
          prev_trap = trap(:SIGINT, 'DEFAULT')

          begin
            line = readline
          rescue Interrupt
            retry
          ensure
            trap(:SIGINT, prev_trap)
          end

          line = (line || 'quit').strip

          if @width_changed
            @width_changed = false
            send "width #{@width}"
          end

          send "command #{line}"
        when /^ask (.*)/
          print $1
          send "answer #{gets || ''}"
        when /^quit/
          raise 'quit'
        else
          puts "(unknown) #{line.inspect}"
        end
      end
    rescue
      STDERR.puts "disconnected (#{$!})"
      exit
    end
  end
end

if __FILE__ == $0
  DEBUGGER__::Client.new(argv).connect
end

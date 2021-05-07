require 'socket'
require_relative 'config'

module DEBUGGER__
  class CommandLineOptionError < Exception; end

  class Client
    begin
      require 'readline'
      def readline
        Readline.readline("\n(rdb) ", true)
      end
    rescue LoadError
      def readline
        print "\n(rdb) "
        gets
      end
    end

    def initialize argv
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

    def connect_unix name = nil
      if name
        if File.exist? name
          @s = Socket.unix(name)
        else
          @s = Socket.unix(File.join(DEBUGGER__.unix_domain_socket_basedir, name))
        end
      else
        cleanup_unix_domain_sockets
        files = Dir.glob(DEBUGGER__.create_unix_domain_socket_name_prefix + '*')
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

    def connect
      trap(:SIGINT){
        @s.puts "pause"
      }

      while line = @s.gets
        # p line: line
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
          @s.puts "command #{line}"
        when /^ask (.*)/
          print $1
          @s.puts "answer #{gets || ''}"
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

def connect argv = ARGV
  DEBUGGER__::Client.new(argv).connect
end

if __FILE__ == $0
  connect
end

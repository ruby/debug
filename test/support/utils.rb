# frozen_string_literal: true

require 'pty'
require 'timeout'
require 'json'

module DEBUGGER__
  module TestUtils
    def type(command)
      @queue.push(command)
    end

    def create_message fail_msg
      "#{fail_msg}\n[DEBUG SESSION LOG]\n> " + @backlog.join('> ')
    end


    def combine_regexps(regexps)
      Regexp.new(regexps.map(&:source).reduce(:+))
    end

    def debug_code(program, **options, &block)
      @queue = Queue.new
      block.call
      write_temp_file(strip_line_num(program))
      create_pseudo_terminal(**options)
      check_line_num!(program)
    end

    DEBUG_MODE = false
    ASK_CMD = %w[quit delete kill]

    def debug_print msg
      print msg if DEBUG_MODE
    end

    RUBY = RbConfig.ruby
    REPL_RPOMPT = /\(rdbg\)/

    def create_pseudo_terminal(boot_options: "-r debug/run")
      inject_lib_to_load_path
      ENV['RUBY_DEBUG_USE_COLORIZE'] = "false"
      ENV['RUBY_DEBUG_TEST_MODE'] = 'true'

      timeout_sec = (ENV['RUBY_DEBUG_TIMEOUT_SEC'] || 10).to_i

      PTY.spawn("#{RUBY} #{boot_options} #{temp_file_path}") do |read, write, pid|
        @backlog = []
        @last_backlog = []
        ask_cmd = ['quit', 'delete', 'kill']
        begin
          Timeout.timeout(timeout_sec) do
            while (line = read.gets)
              debug_print line
              case line.chomp
              when /INTERNAL_INFO:\s(.*)/
                @internal_info = JSON.parse(Regexp.last_match(1))
                cmd = @queue.pop
                if cmd.is_a?(Proc)
                  cmd.call
                  cmd = @queue.pop
                end
                if ASK_CMD.include?(cmd)
                  write.puts(cmd)
                  cmd = @queue.pop
                end
                write.puts(cmd)
                @last_backlog.clear
                next # INTERNAL_INFO shouldn't be pushed into @backlog and @last_backlog
              when REPL_RPOMPT
                # check if the previous command breaks the debugger before continuing
                if error_index = @last_backlog.index { |l| l.match?(/REPL ERROR/) }
                  raise "Debugger terminated because of: #{@last_backlog[error_index..-1].join}"
                end
              end

              @backlog.push(line)
              @last_backlog.push(line)
            end

            assert_empty_queue
          end
        rescue Errno::EIO => e
          # result of `gets` return this exception in some platform
          # https://github.com/ruby/ruby/blob/master/ext/pty/pty.c#L729-L736
          assert_empty_queue(exception: e)
        rescue Timeout::Error => e
          assert false, create_message("TIMEOUT ERROR (#{timeout_sec} sec)")
        end
      end
    end

    private

    # use this to start a debug session with the test program
    def manual_debug_code(program)
      print("[Starting a Debug Session with @#{caller.first}]\n")
      write_temp_file(strip_line_num(program))

      require_relative "../../lib/debug/client"

      socket_path = DEBUGGER__.create_unix_domain_socket_name
      inject_lib_to_load_path
      ENV["RUBY_DEBUG_SOCK_PATH"] = socket_path
      pid = spawn("#{RUBY} -r debug/open #{temp_file_path}")

      while !File.exist?(socket_path)
        sleep 0.1
      end

      DEBUGGER__::Client.new([socket_path]).connect
    ensure
      Process.kill('QUIT', pid)
    end

    def inject_lib_to_load_path
      ENV['RUBYOPT'] = "-I #{__dir__}/../../lib"
    end

    LINE_NUMBER_REGEX = /^\s*\d+\| ?/

    def assert_empty_queue(exception: nil)
      message = "expect all commands/assertions to be executed. still have #{@queue.length} left."
      message += "\nassociated exception: #{exception.class} - #{exception.message}" if exception
      assert_empty @queue, message
    end

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
end

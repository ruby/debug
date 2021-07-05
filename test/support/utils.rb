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
      "#{fail_msg} on #{@mode} mode\n[DEBUG SESSION LOG]\n> " + @backlog.join('> ')
    end

    # This method will execute both local and remote mode by default.
    def debug_code(program, boot_options: '-r debug/run', remote: true, &block)
      check_line_num!(program)

      @scenario = block
      write_temp_file(strip_line_num(program))
      inject_lib_to_load_path

      ENV['RUBY_DEBUG_USE_COLORIZE'] = "false"
      ENV['RUBY_DEBUG_TEST_MODE'] = 'true'

      debug_on_local boot_options

      if remote && !NO_REMOTE
        debug_on_unix_domain_socket
        debug_on_tcpip
      end
    end

    DEBUG_MODE = false
    ASK_CMD = %w[quit delete kill undisplay]

    def debug_print msg
      print msg if DEBUG_MODE
    end

    RUBY = RbConfig.ruby
    RUBY_DEBUG_TEST_PORT = '12345'

    nr = ENV['RUBY_DEBUG_TEST_NO_REMOTE']
    NO_REMOTE = nr == 'true' || nr == '1'

    if !NO_REMOTE
      warn "Tests on local and remote. You can disable remote tests with RUBY_DEBUG_TEST_NO_REMOTE=1."
    end

    def debug_on_local boot_options
      # run test on local mode
      @mode = 'LOCAL'
      repl_prompt = /\(rdbg\)/
      cmd = "#{RUBY} #{boot_options} #{temp_file_path}"
      run_test_scenario(cmd, repl_prompt)
    end

    def debug_on_unix_domain_socket repl_prompt = '(rdbg:remote)'
      @mode = 'UNIX DOMAIN SOCKET'
      boot_options = '-r debug/open'
      cmd = "#{__dir__}/../../exe/rdbg -A"
      setup_remote_debuggee("#{RUBY} #{boot_options} #{temp_file_path}")
      run_test_scenario(cmd, repl_prompt)
    end

    def debug_on_tcpip repl_prompt = '(rdbg:remote)'
      @mode = 'TCP/IP'
      cmd = "#{__dir__}/../../exe/rdbg -A #{RUBY_DEBUG_TEST_PORT}"
      setup_remote_debuggee("#{__dir__}/../../exe/rdbg -O --port=#{RUBY_DEBUG_TEST_PORT} #{temp_file_path}")
      run_test_scenario(cmd, repl_prompt)
    end

    def setup_remote_debuggee(cmd)
      @remote_r, @remote_w, @remote_debuggee_pid = PTY.spawn(cmd, :in=>'/dev/null', :out=>'/dev/null')
      @remote_r.read(1) # wait for the remote server to boot up
    end

    def run_test_scenario(cmd, repl_prompt)
      @queue = Queue.new
      @scenario.call

      timeout_sec = (ENV['RUBY_DEBUG_TIMEOUT_SEC'] || 10).to_i

      PTY.spawn(cmd) do |read, write, pid|
        @backlog = []
        @last_backlog = []
        begin
          Timeout.timeout(timeout_sec) do
            while (line = read.gets)
              debug_print line
              case line.chomp
              when /INTERNAL_INFO:\s(.*)/
                @internal_info = JSON.parse(Regexp.last_match(1))
                cmd = @queue.pop
                while cmd.is_a?(Proc)
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
              when repl_prompt
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
        ensure
          # kill remote debuggee
          if defined?(@remote_debuggee_pid) && @remote_debuggee_pid
            @remote_r.close
            @remote_w.close
            Process.kill(:KILL, @remote_debuggee_pid)
            Process.waitpid(@remote_debuggee_pid)
            @remote_debuggee_pid = nil
          end

          # kill debug console process
          read.close
          write.close
          Process.kill(:KILL, pid)
          Process.waitpid pid
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
      if exception
        message += "\nassociated exception: #{exception.class} - #{exception.message}" +
                   exception.backtrace.map{|l| "  #{l}\n"}.join +
                   "\n[BACKLOG]\n" + @backlog.map{|l| "  #{l}"}.join
      end
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

# frozen_string_literal: true

require 'pty'
require 'timeout'
require 'json'
require_relative "../../lib/debug/client"

module DEBUGGER__
  module TestUtils
    def type(command)
      @queue.push(command)
    end

    def create_message fail_msg
      "#{fail_msg} on #{@mode} mode\n[DEBUGGER SESSION LOG]\n> #{@backlog.join('> ')}#{debuggee_backlog}"
    end

    def debuggee_backlog
      return if @mode == 'LOCAL'

      backlog = []
      begin
        Timeout.timeout(TIMEOUT_SEC) do
          while (line = @remote_r.gets)
            backlog << line
          end
        end
      rescue Timeout::Error, Errno::EIO
        # result of `gets` return Errno::EIO in some platform
        # https://github.com/ruby/ruby/blob/master/ext/pty/pty.c#L729-L736
      end
      "\n[DEBUGGEE SESSION LOG]\n> #{backlog.join('> ')}"
    end

    # This method will execute both local and remote mode by default.
    def debug_code(program, boot_options: '-r debug/start', remote: true, &block)
      check_line_num!(program)

      @scenario = block
      write_temp_file(strip_line_num(program))
      inject_lib_to_load_path

      ENV['RUBY_DEBUG_NO_COLOR'] = 'true'
      ENV['RUBY_DEBUG_TEST_MODE'] = 'true'

      debug_on_local boot_options

      if remote && !NO_REMOTE
        debug_on_unix_domain_socket
        debug_on_tcpip
      end
    end

    ASK_CMD = %w[quit q delete del kill undisplay]

    def debug_print msg
      print msg if ENV['RUBY_DEBUG_TEST_DEBUG_MODE']
    end

    RDBG_EXECUTABLE = "#{__dir__}/../../exe/rdbg"
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

    def debug_on_unix_domain_socket repl_prompt = /\(rdbg:remote\)/
      @mode = 'UNIX DOMAIN SOCKET'
      socket_path = setup_unix_doman_socket_remote_debuggee
      cmd = "#{RDBG_EXECUTABLE} -A #{socket_path}"
      run_test_scenario(cmd, repl_prompt)
    end

    def debug_on_tcpip repl_prompt = /\(rdbg:remote\)/
      @mode = 'TCP/IP'
      cmd = "#{RDBG_EXECUTABLE} -A #{RUBY_DEBUG_TEST_PORT}"
      setup_remote_debuggee("#{RDBG_EXECUTABLE} -O --port=#{RUBY_DEBUG_TEST_PORT} -- #{temp_file_path}")
      run_test_scenario(cmd, repl_prompt)
    end

    TIMEOUT_SEC = (ENV['RUBY_DEBUG_TIMEOUT_SEC'] || 10).to_i

    def run_test_scenario(cmd, repl_prompt)
      @queue = Queue.new
      @scenario.call

      PTY.spawn(cmd) do |read, write, pid|
        @backlog = []
        @last_backlog = []
        begin
          Timeout.timeout(TIMEOUT_SEC) do
            while (line = read.gets)
              debug_print line
              @backlog.push(line)
              @last_backlog.push(line)

              case line.chomp
              when /INTERNAL_INFO:\s(.*)/
                # INTERNAL_INFO shouldn't be pushed into @backlog and @last_backlog
                @backlog.pop
                @last_backlog.pop

                @internal_info = JSON.parse(Regexp.last_match(1))
                cmd = @queue.pop
                while cmd.is_a?(Proc)
                  cmd.call
                  cmd = @queue.pop
                end
                if ASK_CMD.include?(cmd)
                  write.puts(cmd)
                  cmd = @queue.pop
                  if cmd.is_a?(Proc)
                    assertion = cmd
                    cmd = @queue.pop
                  end
                end

                write.puts(cmd)
                @last_backlog.clear
                next # INTERNAL_INFO shouldn't be pushed into @backlog and @last_backlog
              when %r{\[y/n\]}i
                assertion&.call
              when repl_prompt
                # check if the previous command breaks the debugger before continuing
                check_error(/REPL ERROR/)
              end
            end

            check_error(/DEBUGGEE Exception/)
            assert_empty_queue
          end
        # result of `gets` return this exception in some platform
        # https://github.com/ruby/ruby/blob/master/ext/pty/pty.c#L729-L736
        rescue Errno::EIO => e
          check_error(/DEBUGGEE Exception/)
          assert_empty_queue(exception: e)
        rescue Timeout::Error => e
          assert false, create_message("TIMEOUT ERROR (#{TIMEOUT_SEC} sec)")
        ensure
          kill_remote_debuggee
          # kill debug console process
          read.close
          write.close
          Process.kill(:KILL, pid)
          Process.waitpid pid
        end
      end
    end

    private

    def check_error(error)
      if error_index = @last_backlog.index { |l| l.match?(error) }
        raise create_message("Debugger terminated because of: #{@last_backlog[error_index..-1].join}")
      end
    end

    def kill_remote_debuggee
      if defined?(@remote_debuggee_pid) && @remote_debuggee_pid
        @remote_r.close
        @remote_w.close
        Process.kill(:KILL, @remote_debuggee_pid)
        Process.waitpid(@remote_debuggee_pid)
        @remote_debuggee_pid = nil
      end
    end

    # use this to start a debug session with the test program
    def manual_debug_code(program)
      print("[Starting a Debug Session with @#{caller.first}]\n")
      write_temp_file(strip_line_num(program))
      socket_path = setup_unix_doman_socket_remote_debuggee

      while !File.exist?(socket_path)
        sleep 0.1
      end

      DEBUGGER__::Client.new([socket_path]).connect
    ensure
      kill_remote_debuggee
    end

    def setup_unix_doman_socket_remote_debuggee
      socket_path = DEBUGGER__.create_unix_domain_socket_name
      setup_remote_debuggee("#{RDBG_EXECUTABLE} -O --sock-path=#{socket_path} #{temp_file_path}")
      socket_path
    end

    def setup_remote_debuggee(cmd)
      @remote_r, @remote_w, @remote_debuggee_pid = PTY.spawn(cmd)
      @remote_r.read(1) # wait for the remote server to boot up
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

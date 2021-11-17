# frozen_string_literal: true

require 'pty'
require 'timeout'
require 'json'
require 'rbconfig'
require_relative "../../lib/debug/client"

module DEBUGGER__
  module TestUtils
    def type(command)
      @scenario.push(command)
    end

    def create_message fail_msg, test_info
      debugger_msg = <<~DEBUGGER_MSG.chomp
        --------------------
        | Debugger Session |
        --------------------

        > #{test_info.backlog.join('> ')}
      DEBUGGER_MSG

      debuggee_msg =
        if test_info.mode != 'LOCAL'
          <<~DEBUGGEE_MSG.chomp
            --------------------
            | Debuggee Session |
            --------------------

            > #{test_info.remote_info.debuggee_backlog.join('> ')}
          DEBUGGEE_MSG
        end

      failure_msg = <<~FAILURE_MSG.chomp
        -------------------
        | Failure Message |
        -------------------

        #{fail_msg} on #{test_info.mode} mode
      FAILURE_MSG

      <<~MSG.chomp

        #{debugger_msg}

        #{debuggee_msg}

        #{failure_msg}
      MSG
    end

    TestInfo = Struct.new(:queue, :mode, :prompt_pattern, :remote_info,
                          :backlog, :last_backlog, :internal_info, :failed_process)

    RemoteInfo = Struct.new(:r, :w, :pid, :sock_path, :port, :reader_thread, :debuggee_backlog)

    MULTITHREADED_TEST = !(%w[1 true].include? ENV['RUBY_DEBUG_TEST_DISABLE_THREADS'])

    def debug_code(program, remote: true, &test_steps)
      prepare_test_environment(program, test_steps) do
        if remote && !NO_REMOTE && MULTITHREADED_TEST
          begin
            th = [
              new_thread { debug_code_on_local },
              new_thread { debug_code_on_unix_domain_socket },
              new_thread { debug_code_on_tcpip },
            ]

            th.each do |t|
              if fail_msg = t.join.value
                th.each(&:kill)
                flunk fail_msg
              end
            end
          rescue Exception => e
            th.each(&:kill)
            flunk e.inspect
          end
        elsif remote && !NO_REMOTE
          debug_code_on_local
          debug_code_on_unix_domain_socket
          debug_code_on_tcpip
        else
          debug_code_on_local
        end
      end
    end

    private def debug_code_on_local
      test_info = TestInfo.new(dup_scenario, 'LOCAL', /\(rdbg\)/)
      cmd = "#{RDBG_EXECUTABLE} #{temp_file_path}"
      run_test_scenario cmd, test_info
    end

    private def debug_code_on_unix_domain_socket
      test_info = TestInfo.new(dup_scenario, 'UNIX Domain Socket', /\(rdbg:remote\)/)
      test_info.remote_info = setup_unix_doman_socket_remote_debuggee
      cmd = "#{RDBG_EXECUTABLE} -A #{test_info.remote_info.sock_path}"
      run_test_scenario cmd, test_info
    end

    private def debug_code_on_tcpip
      test_info = TestInfo.new(dup_scenario, 'TCP/IP', /\(rdbg:remote\)/)
      test_info.remote_info = setup_tcpip_remote_debuggee
      cmd = "#{RDBG_EXECUTABLE} -A #{test_info.remote_info.port}"
      run_test_scenario cmd, test_info
    end

    def run_ruby program, options: nil, &test_steps
      prepare_test_environment(program, test_steps) do
        test_info = TestInfo.new(dup_scenario, 'LOCAL', /\(rdbg\)/)
        cmd = "#{RUBY} #{options} -- #{temp_file_path}"
        run_test_scenario cmd, test_info
      end
    end

    def run_rdbg program, options: nil, &test_steps
      prepare_test_environment(program, test_steps) do
        test_info = TestInfo.new(dup_scenario, 'LOCAL', /\(rdbg\)/)
        cmd = "#{RDBG_EXECUTABLE} #{options} -- #{temp_file_path}"
        run_test_scenario cmd, test_info
      end
    end

    def dup_scenario
      @scenario.each_with_object(Queue.new){ |e, q| q << e }
    end

    def new_thread &block
      Thread.new do
        Thread.current[:is_subthread] = true
        catch(:fail) do
          block.call
        end
      end
    end

    def multithreaded_test?
      Thread.current[:is_subthread]
    end

    ASK_CMD = %w[quit q delete del kill undisplay].freeze

    def debug_print msg
      print msg if ENV['RUBY_DEBUG_TEST_DEBUG_MODE']
    end

    RUBY = ENV['RUBY'] || RbConfig.ruby
    RDBG_EXECUTABLE = "#{RUBY} #{__dir__}/../../exe/rdbg"

    nr = ENV['RUBY_DEBUG_TEST_NO_REMOTE']
    NO_REMOTE = nr == 'true' || nr == '1'

    if !NO_REMOTE
      warn "Tests on local and remote. You can disable remote tests with RUBY_DEBUG_TEST_NO_REMOTE=1."
    end

    def prepare_test_environment(program, test_steps, &block)
      write_temp_file(strip_line_num(program))
      @scenario = []
      test_steps.call
      @scenario.freeze
      inject_lib_to_load_path

      ENV['RUBY_DEBUG_NO_COLOR'] = 'true'
      ENV['RUBY_DEBUG_TEST_MODE'] = 'true'
      ENV['RUBY_DEBUG_NO_RELINE'] = 'true'
      ENV['RUBY_DEBUG_HISTORY_FILE'] = ''

      block.call

      check_line_num!(program)

      assert true
    end

    TIMEOUT_SEC = (ENV['RUBY_DEBUG_TIMEOUT_SEC'] || 10).to_i

    def run_test_scenario cmd, test_info
      PTY.spawn(cmd) do |read, write, pid|
        test_info.backlog = []
        test_info.last_backlog = []
        begin
          Timeout.timeout(TIMEOUT_SEC) do
            while (line = read.gets)
              debug_print line
              test_info.backlog.push(line)
              test_info.last_backlog.push(line)

              case line.chomp
              when /INTERNAL_INFO:\s(.*)/
                # INTERNAL_INFO shouldn't be pushed into backlog and last_backlog
                test_info.backlog.pop
                test_info.last_backlog.pop

                test_info.internal_info = JSON.parse(Regexp.last_match(1))
                assertion = []
                is_ask_cmd = false

                loop do
                  assert_block(FailureMessage.new { create_message "Expected the REPL prompt to finish", test_info }) { !test_info.queue.empty? }
                  cmd = test_info.queue.pop

                  case cmd.to_s
                  when /Proc/
                    if is_ask_cmd
                      assertion.push cmd
                    else
                      cmd.call test_info
                    end
                  when /flunk_finish/
                    cmd.call test_info
                  when *ASK_CMD
                    write.puts cmd
                    is_ask_cmd = true
                  else
                    break
                  end
                end

                write.puts(cmd)
                test_info.last_backlog.clear
              when %r{\[y/n\]}i
                assertion.each do |a|
                  a.call test_info
                end
              when test_info.prompt_pattern
                # check if the previous command breaks the debugger before continuing
                check_error(/REPL ERROR/, test_info)
              end
            end

            check_error(/DEBUGGEE Exception/, test_info)
            assert_empty_queue test_info
          end
        # result of `gets` return this exception in some platform
        # https://github.com/ruby/ruby/blob/master/ext/pty/pty.c#L729-L736
        rescue Errno::EIO => e
          check_error(/DEBUGGEE Exception/, test_info)
          assert_empty_queue test_info, exception: e
        rescue Timeout::Error
          assert_block(create_message("TIMEOUT ERROR (#{TIMEOUT_SEC} sec)", test_info)) { false }
        ensure
          kill_remote_debuggee test_info
          # kill debug console process
          read.close
          write.close
          kill_safely pid, :debugger, test_info
          if name = test_info.failed_process
            assert_block(create_message("Expected the #{name} program to finish", test_info)) { false }
          end
        end
      end
    end

    private

    def wait_pid pid, sec
      total_sec = 0.0
      wait_sec = 0.001 # 0.1ms

      while total_sec < sec
        if Process.waitpid(pid, Process::WNOHANG) == pid
          return true
        end
        sleep wait_sec
        total_sec += wait_sec
        wait_sec *= 2
      end

      false
    end

    def kill_safely pid, name, test_info
      return if wait_pid pid, 3
      
      test_info.failed_process = name

      Process.kill :TERM, pid
      return if wait_pid pid, 0.2

      Process.kill :KILL, pid
      Process.waitpid(pid)
    rescue Errno::EPERM, Errno::ESRCH
    end

    def temp_file_path
      @temp_file.path
    end

    def write_temp_file(program)
      @temp_file = Tempfile.create(%w[debug- .rb])
      @temp_file.write(program)
      @temp_file.close
    end

    def check_error(error, test_info)
      if error_index = test_info.last_backlog.index { |l| l.match?(error) }
        assert_block(create_message("Debugger terminated because of: #{test_info.last_backlog[error_index..-1].join}", test_info)) { false }
      end
    end

    def kill_remote_debuggee test_info
      return unless r = test_info.remote_info

      r.reader_thread.kill
      r.r.close
      r.w.close
      kill_safely r.pid, :remote, test_info
    end

    # use this to start a debug session with the test program
    def manual_debug_code(program)
      print("[Starting a Debug Session with @#{caller.first}]\n")
      write_temp_file(strip_line_num(program))
      remote_info = setup_unix_doman_socket_remote_debuggee

      while !File.exist?(remote_info.sock_path)
        sleep 0.1
      end

      DEBUGGER__::Client.new([socket_path]).connect
    ensure
      kill_remote_debuggee remote_info
    end

    def setup_remote_debuggee(cmd)
      remote_info = RemoteInfo.new(*PTY.spawn(cmd))
      remote_info.r.read(1) # wait for the remote server to boot up
      remote_info.debuggee_backlog = []

      remote_info.reader_thread = Thread.new(remote_info) do |info|
        while data = info.r.gets
          info.debuggee_backlog << data
        end
      rescue Errno::EIO
      end
      remote_info
    end

    $ruby_debug_test_num = 0

    def setup_unix_doman_socket_remote_debuggee
      sock_path = DEBUGGER__.create_unix_domain_socket_name + "-#{$ruby_debug_test_num += 1}"
      remote_info = setup_remote_debuggee("#{RDBG_EXECUTABLE} -O --sock-path=#{sock_path} #{temp_file_path}")
      remote_info.sock_path = sock_path
      sleep 0.1 while !File.exist?(sock_path) && Process.kill(0, remote_info.pid)
      remote_info
    end

    # search free port by opening server socket with port 0
    Socket.tcp_server_sockets(0).tap do |ss|
      TCPIP_PORT = ss.first.local_address.ip_port
    end.each{|s| s.close}

    def setup_tcpip_remote_debuggee
      remote_info = setup_remote_debuggee("#{RDBG_EXECUTABLE} -O --port=#{TCPIP_PORT} -- #{temp_file_path}")
      remote_info.port = TCPIP_PORT
      remote_info
    end

    def inject_lib_to_load_path
      ENV['RUBYOPT'] = "-I #{__dir__}/../../lib"
    end

    LINE_NUMBER_REGEX = /^\s*\d+\| ?/

    def assert_empty_queue test_info, exception: nil
      message = "Expected all commands/assertions to be executed. Still have #{test_info.queue.length} left."
      if exception
        message += "\nAssociated exception: #{exception.class} - #{exception.message}" +
                   exception.backtrace.map{|l| "  #{l}\n"}.join
      end
      assert_block(FailureMessage.new { create_message message, test_info }) { test_info.queue.empty? }
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

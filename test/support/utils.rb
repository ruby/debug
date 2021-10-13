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
          debuggee_backlog = collect_debuggee_backlog(test_info)

          <<~DEBUGGEE_MSG.chomp
            --------------------
            | Debuggee Session |
            --------------------

            > #{debuggee_backlog.join('> ')}
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

    def collect_debuggee_backlog test_info
      backlog = []

      begin
        Timeout.timeout(TIMEOUT_SEC) do
          while (line = test_info.remote_debuggee_info[0].gets)
            backlog << line
          end
        end
      rescue Timeout::Error, Errno::EIO
        # result of `gets` return Errno::EIO in some platform
        # https://github.com/ruby/ruby/blob/master/ext/pty/pty.c#L729-L736
      end
      backlog
    end

    TestInfo = Struct.new(:queue, :remote_debuggee_info, :mode, :backlog, :last_backlog, :internal_info)

    MULTITHREADED_TEST = !(%w[1 true].include? ENV['RUBY_DEBUG_TEST_DISABLE_THREADS'])

    # This method will execute both local and remote mode by default.
    def debug_code(program, boot_options: '-r debug/start', remote: true, &block)
      write_temp_file(strip_line_num(program))
      @scenario = []
      block.call
      @scenario.freeze
      inject_lib_to_load_path

      ENV['RUBY_DEBUG_NO_COLOR'] = 'true'
      ENV['RUBY_DEBUG_TEST_MODE'] = 'true'
      ENV['RUBY_DEBUG_NO_RELINE'] = 'true'
      ENV['RUBY_DEBUG_HISTORY_FILE'] = ''

      if remote && !NO_REMOTE && MULTITHREADED_TEST
        begin
          th = [new_thread { debug_on_local boot_options, TestInfo.new(dup_scenario) },
                new_thread { debug_on_unix_domain_socket TestInfo.new(dup_scenario) },
                new_thread { debug_on_tcpip TestInfo.new(dup_scenario) }]
          th.each do |t|
            if fail_msg = t.join.value
              th.each(&:kill)
              flunk fail_msg
            end
          end
        rescue => e
          th.each(&:kill)
          flunk e.inspect
        end
      elsif remote && !NO_REMOTE
        debug_on_local boot_options, TestInfo.new(dup_scenario)
        debug_on_unix_domain_socket TestInfo.new(dup_scenario)
        debug_on_tcpip TestInfo.new(dup_scenario)
      else
        debug_on_local boot_options, TestInfo.new(dup_scenario)
      end

      check_line_num!(program)

      assert true
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
    RUBY_DEBUG_TEST_PORT = '12345'

    nr = ENV['RUBY_DEBUG_TEST_NO_REMOTE']
    NO_REMOTE = nr == 'true' || nr == '1'

    if !NO_REMOTE
      warn "Tests on local and remote. You can disable remote tests with RUBY_DEBUG_TEST_NO_REMOTE=1."
    end

    def debug_on_local boot_options, test_info
      test_info.mode = 'LOCAL'
      repl_prompt = /\(rdbg\)/
      cmd = "#{RUBY} #{boot_options} #{temp_file_path}"
      run_test_scenario cmd, repl_prompt, test_info
    end

    def debug_on_unix_domain_socket repl_prompt = /\(rdbg:remote\)/, test_info
      test_info.mode = 'UNIX DOMAIN SOCKET'
      socket_path, remote_debuggee_info = setup_unix_doman_socket_remote_debuggee
      test_info.remote_debuggee_info = remote_debuggee_info
      cmd = "#{RDBG_EXECUTABLE} -A #{socket_path}"
      run_test_scenario cmd, repl_prompt, test_info
    end

    def debug_on_tcpip repl_prompt = /\(rdbg:remote\)/, test_info
      test_info.mode = 'TCP/IP'
      cmd = "#{RDBG_EXECUTABLE} -A #{RUBY_DEBUG_TEST_PORT}"
      remote_debuggee_info = setup_remote_debuggee("#{RDBG_EXECUTABLE} -O --port=#{RUBY_DEBUG_TEST_PORT} -- #{temp_file_path}")
      test_info.remote_debuggee_info = remote_debuggee_info
      run_test_scenario cmd, repl_prompt, test_info
    end

    TIMEOUT_SEC = (ENV['RUBY_DEBUG_TIMEOUT_SEC'] || 10).to_i

    def run_test_scenario cmd, repl_prompt, test_info
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
              when repl_prompt
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
        rescue Timeout::Error => e
          assert_block(create_message("TIMEOUT ERROR (#{TIMEOUT_SEC} sec)", test_info)) { false }
        ensure
          kill_remote_debuggee test_info.remote_debuggee_info
          # kill debug console process
          read.close
          write.close
          Process.kill(:KILL, pid)
          Process.waitpid pid
        end
      end
    end

    private

    def check_error(error, test_info)
      if error_index = test_info.last_backlog.index { |l| l.match?(error) }
        assert_block(create_message("Debugger terminated because of: #{test_info.last_backlog[error_index..-1].join}", test_info)) { false }
      end
    end

    def kill_remote_debuggee remote_debuggee_info
      return unless remote_debuggee_info

      remote_r, remote_w, remote_debuggee_pid = remote_debuggee_info
      remote_r.close
      remote_w.close
      Process.kill(:KILL, remote_debuggee_pid)
      Process.waitpid(remote_debuggee_pid)
    end

    # use this to start a debug session with the test program
    def manual_debug_code(program)
      print("[Starting a Debug Session with @#{caller.first}]\n")
      write_temp_file(strip_line_num(program))
      socket_path, remote_debuggee_info = setup_unix_doman_socket_remote_debuggee

      while !File.exist?(socket_path)
        sleep 0.1
      end

      DEBUGGER__::Client.new([socket_path]).connect
    ensure
      kill_remote_debuggee(remote_debuggee_info)
    end

    def setup_unix_doman_socket_remote_debuggee
      socket_path = DEBUGGER__.create_unix_domain_socket_name
      remote_debuggee_info = setup_remote_debuggee("#{RDBG_EXECUTABLE} -O --sock-path=#{socket_path} #{temp_file_path}")
      [socket_path, remote_debuggee_info]
    end

    def setup_remote_debuggee(cmd)
      remote_r, remote_w, remote_debuggee_pid = PTY.spawn(cmd)
      remote_r.read(1) # wait for the remote server to boot up
      [remote_r, remote_w, remote_debuggee_pid]
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
      assert_block(FailureMessage.new { create_message message, test_info }) do
        return true if test_info.queue.empty?

        case test_info.queue.pop.to_s
        when /flunk_finish/
          true
        else
          false
        end
      end
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

require_relative "test_case"

module DEBUGGER__
  class ConsoleTestCase < TestCase
    nr = ENV['RUBY_DEBUG_TEST_NO_REMOTE']
    NO_REMOTE = nr == 'true' || nr == '1'

    if !NO_REMOTE
      warn "Tests on local and remote. You can disable remote tests with RUBY_DEBUG_TEST_NO_REMOTE=1."
    end

    # CIs usually doesn't allow overriding the HOME path
    # we also don't need to worry about adding or being affected by ~/.rdbgrc on CI
    # so we can just use the original home page there
    USE_TMP_HOME =
      !ENV["CI"] ||
      begin
        pwd = Dir.pwd
        ruby = ENV['RUBY'] || RbConfig.ruby
        home_cannot_change = false
        PTY.spawn({ "HOME" => pwd }, ruby, '-e', 'puts ENV["HOME"]') do |r,|
          home_cannot_change = r.gets.chomp != pwd
        end
        home_cannot_change
      end

    class << self
      attr_reader :pty_home_dir

      def startup
        @pty_home_dir =
          if USE_TMP_HOME
            Dir.mktmpdir
          else
            Dir.home
          end
      end

      def shutdown
        if USE_TMP_HOME
          FileUtils.remove_entry @pty_home_dir
        end
      end
    end

    def pty_home_dir
      self.class.pty_home_dir
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

    def debug_code(program, remote: true, &test_steps)
      Timeout.timeout(60) do
        prepare_test_environment(program, test_steps) do
          if remote && !NO_REMOTE && MULTITHREADED_TEST
            begin
              th = [
                (new_thread { debug_code_on_local } unless remote == :remote_only),
                new_thread { debug_code_on_unix_domain_socket },
                new_thread { debug_code_on_tcpip },
              ].compact

              th.each do |t|
                if fail_msg = t.join.value
                  th.each(&:kill)
                  flunk fail_msg
                end
              end
            rescue Exception => e
              th.each(&:kill)
              flunk "#{e.class.name}: #{e.message}"
            ensure
              th.each {|t| t.join}
            end
          elsif remote && !NO_REMOTE
            debug_code_on_local unless remote == :remote_only
            debug_code_on_unix_domain_socket
            debug_code_on_tcpip
          else
            debug_code_on_local unless remote == :remote_only
          end
        end
      end
    end

    def run_test_scenario cmd, test_info
      PTY.spawn({ "HOME" => pty_home_dir }, cmd) do |read, write, pid|
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

          if r = test_info.remote_info
            assert_program_finish test_info, r.pid, :debuggee
          end

          assert_program_finish test_info, pid, :debugger
        # result of `gets` return this exception in some platform
        # https://github.com/ruby/ruby/blob/master/ext/pty/pty.c#L729-L736
        rescue Errno::EIO => e
          check_error(/DEBUGGEE Exception/, test_info)
          assert_empty_queue test_info, exception: e
          if r = test_info.remote_info
            assert_program_finish test_info, r.pid, :debuggee
          end

          assert_program_finish test_info, pid, :debugger
        # result of `gets` return this exception in some platform
        rescue Timeout::Error
          assert_block(create_message("TIMEOUT ERROR (#{TIMEOUT_SEC} sec)", test_info)) { false }
        ensure
          kill_remote_debuggee test_info
          # kill debug console process
          read.close
          write.close
          kill_safely pid, :debugger, test_info
        end
      end
    end

    def assert_program_finish test_info, pid, name
      assert_block(create_message("Expected the #{name} program to finish", test_info)) { wait_pid pid, TIMEOUT_SEC }
    end

    def prepare_test_environment(program, test_steps, &block)
      ENV['RUBY_DEBUG_NO_COLOR'] = 'true'
      ENV['RUBY_DEBUG_TEST_UI'] = 'terminal'
      ENV['RUBY_DEBUG_NO_RELINE'] = 'true'
      ENV['RUBY_DEBUG_HISTORY_FILE'] = ''

      write_temp_file(strip_line_num(program))
      @scenario = []
      test_steps.call
      @scenario.freeze
      inject_lib_to_load_path

      block.call

      check_line_num!(program)

      assert true
    end

    # use this to start a debug session with the test program
    def manual_debug_code(program)
      print("[Starting a Debug Session with @#{caller.first}]\n")
      write_temp_file(strip_line_num(program))
      remote_info = setup_unix_domain_socket_remote_debuggee

      Timeout.timeout(TIMEOUT_SEC) do
        while !File.exist?(remote_info.sock_path)
          sleep 0.1
        end
      end

      DEBUGGER__::Client.new([socket_path]).connect
    ensure
      kill_remote_debuggee remote_info
    end

    private def debug_code_on_local
      test_info = TestInfo.new(dup_scenario, 'LOCAL', /\(rdbg\)/)
      cmd = "#{RDBG_EXECUTABLE} #{temp_file_path}"
      run_test_scenario cmd, test_info
    end

    private def debug_code_on_unix_domain_socket
      test_info = TestInfo.new(dup_scenario, 'UNIX Domain Socket', /\(rdbg:remote\)/)
      test_info.remote_info = setup_unix_domain_socket_remote_debuggee
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

    def run_rdbg program, options: nil, rubyopt: nil, &test_steps
      prepare_test_environment(program, test_steps) do
        test_info = TestInfo.new(dup_scenario, 'LOCAL', /\(rdbg\)/)
        cmd = "#{RDBG_EXECUTABLE} #{options} -- #{temp_file_path}"
        cmd = "RUBYOPT=#{rubyopt} #{cmd}" if rubyopt
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

    def inject_lib_to_load_path
      ENV['RUBYOPT'] = "-I #{__dir__}/../../lib"
    end

    def assert_empty_queue test_info, exception: nil
      message = "Expected all commands/assertions to be executed. Still have #{test_info.queue.length} left."
      if exception
        message += "\nAssociated exception: #{exception.class} - #{exception.message}" +
                   exception.backtrace.map{|l| "  #{l}\n"}.join
      end
      assert_block(FailureMessage.new { create_message message, test_info }) { test_info.queue.empty? }
    end
  end
end

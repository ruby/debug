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

    def multithreaded_test?
      Thread.current[:is_subthread]
    end

    ASK_CMD = %w[quit q delete del kill undisplay].freeze

    def debug_print msg
      print msg if ENV['RUBY_DEBUG_TEST_DEBUG_MODE']
    end

    RUBY = ENV['RUBY'] || RbConfig.ruby
    RDBG_EXECUTABLE = "#{RUBY} #{__dir__}/../../exe/rdbg"

    TIMEOUT_SEC = (ENV['RUBY_DEBUG_TIMEOUT_SEC'] || 10).to_i

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

    def setup_remote_debuggee(cmd)
      remote_info = DEBUGGER__::TestCase::RemoteInfo.new(*PTY.spawn(cmd))
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

    def setup_unix_domain_socket_remote_debuggee
      sock_path = DEBUGGER__.create_unix_domain_socket_name + "-#{$ruby_debug_test_num += 1}"
      remote_info = setup_remote_debuggee("#{RDBG_EXECUTABLE} -O --sock-path=#{sock_path} #{temp_file_path}")
      remote_info.sock_path = sock_path

      Timeout.timeout(TIMEOUT_SEC) do
        sleep 0.1 while !File.exist?(sock_path) && Process.kill(0, remote_info.pid)
      end

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
  end
end

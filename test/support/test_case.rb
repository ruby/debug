# frozen_string_literal: true

require 'test/unit'
require 'tempfile'
require 'securerandom'
require 'pty'
require 'timeout'
require 'json'
require 'rbconfig'
require_relative '../../lib/debug/client'

require_relative 'assertions'

module DEBUGGER__
  class TestCase < Test::Unit::TestCase
    TestInfo = Struct.new(:queue, :mode, :prompt_pattern, :remote_info,
                          :backlog, :last_backlog, :internal_info, :failed_process)

    RemoteInfo = Struct.new(:r, :w, :pid, :sock_path, :port, :reader_thread, :debuggee_backlog)

    MULTITHREADED_TEST = !(%w[1 true].include? ENV['RUBY_DEBUG_TEST_DISABLE_THREADS'])

    include AssertionHelpers

    def setup
      @temp_file = nil
    end

    def teardown
      remove_temp_file
    end

    def temp_file_path
      @temp_file.path
    end

    def remove_temp_file
      File.unlink(@temp_file) if @temp_file
      @temp_file = nil
    end

    def write_temp_file(program)
      @temp_file = Tempfile.create(%w[debug- .rb])
      @temp_file.write(program)
      @temp_file.close
    end

    def with_extra_tempfile(*additional_words)
      name = SecureRandom.hex(5) + additional_words.join

      t = Tempfile.create([name, '.rb']).tap do |f|
        f.write(extra_file)
        f.close
      end
      yield t
    ensure
      File.unlink t if t
    end

    LINE_NUMBER_REGEX = /^\s*\d+\| ?/

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

    def get_target_ui
      ENV['RUBY_DEBUG_TEST_UI']
    end

    private

    def wait_pid pid, sec
      total_sec = 0.0
      wait_sec = 0.001 # 1ms

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

      kill_safely r.pid, :remote, test_info
      r.reader_thread.kill
      # Because the debuggee may be terminated by executing the following operations, we need to run them after `kill_safely` method.
      r.r.close
      r.w.close
    end

    def setup_remote_debuggee(cmd)
      homedir = defined?(self.class.pty_home_dir) ? self.class.pty_home_dir : ENV['HOME']

      remote_info = DEBUGGER__::TestCase::RemoteInfo.new(*PTY.spawn({'HOME' => homedir}, cmd))
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

    # Debuggee sometimes sends msgs such as "out [1, 5] in ...".
    # This http request method is for ignoring them.
    def get_request host, port, path
      Timeout.timeout(TIMEOUT_SEC) do
        Socket.tcp(host, port){|sock|
          sock.print "GET #{path} HTTP/1.1\r\n"
          sock.close_write
          loop do
            case header = sock.gets
            when /Content-Length: (\d+)/
              b = sock.read(2)
              raise b.inspect unless b == "\r\n"
      
              l = sock.read $1.to_i
              return JSON.parse l, symbolize_names: true
            end
          end
        }
      end
    end
  end
end

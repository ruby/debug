# frozen_string_literal: true

require_relative '../support/console_test_case'
require 'debug/session'
require 'debug/server'

module DEBUGGER__
  class OpenProctitleParseTest < ConsoleTestCase
    def test_parses_string_as_exact_match
      assert_equal 'worker', UI_TcpServer.parse_open_proctitle('worker')
    end

    def test_parses_slash_delimited_value_as_regexp
      result = UI_TcpServer.parse_open_proctitle('/worker.*/')
      assert_kind_of Regexp, result
      assert_equal(/worker.*/, result)
    end

    def test_parses_regexp_flags
      result = UI_TcpServer.parse_open_proctitle('/worker/i')
      assert_kind_of Regexp, result
      assert_equal Regexp::IGNORECASE, result.options & Regexp::IGNORECASE
    end

    def test_invalid_regexp_raises_argument_error
      assert_raise_message(/Invalid RUBY_DEBUG_OPEN_PROCTITLE regexp/) do
        UI_TcpServer.parse_open_proctitle('/[invalid/')
      end
    end

    def test_nil_returns_nil
      assert_nil UI_TcpServer.parse_open_proctitle(nil)
    end

    def test_path_starting_with_slash_is_exact_string
      # Only "/.../[flags]" is regexp; arbitrary strings starting with `/`
      # but not ending with `/` are exact-match strings.
      assert_equal '/usr/bin/foo', UI_TcpServer.parse_open_proctitle('/usr/bin/foo')
    end
  end

  class OpenProctitleInitTest < ConsoleTestCase
    def teardown
      super
      CONFIG[:open_proctitle] = nil
    end

    def test_invalid_regexp_raises_at_initialize
      CONFIG[:open_proctitle] = '/[invalid/'

      assert_raise_message(/Invalid RUBY_DEBUG_OPEN_PROCTITLE/) do
        UI_TcpServer.new(port: 0)
      end
    end

    def test_regexp_value_is_compiled_to_regexp
      CONFIG[:open_proctitle] = '/worker.*/'
      server = UI_TcpServer.new(port: 0)
      compiled = server.instance_variable_get(:@open_proctitle)

      assert_kind_of Regexp, compiled
      assert_equal(/worker.*/, compiled)
    end

    def test_string_value_is_kept_as_string
      CONFIG[:open_proctitle] = 'my-worker'
      server = UI_TcpServer.new(port: 0)
      kept = server.instance_variable_get(:@open_proctitle)

      assert_kind_of String, kept
      assert_equal 'my-worker', kept
    end

    def test_no_value_leaves_attribute_nil
      CONFIG[:open_proctitle] = nil
      server = UI_TcpServer.new(port: 0)
      assert_nil server.instance_variable_get(:@open_proctitle)
    end
  end

  class OpenProctitleRemoteTest < ConsoleTestCase
    def program
      <<~RUBY
        1| a = 1
        2| b = 2
      RUBY
    end

    # When $0 matches the regexp form, the TCP port is opened normally and
    # the debugger logs the match.
    def test_port_opens_when_regexp_matches
      omit "no remote tests" if NO_REMOTE

      write_temp_file(strip_line_num(program))
      basename = Regexp.escape(File.basename(temp_file_path))
      cmd = "#{RDBG_EXECUTABLE} -O --port=0 --open-proctitle=/#{basename}/ -- #{temp_file_path}"

      remote_info = setup_remote_debuggee(cmd)
      assert remote_info.debuggee_backlog.any? { |l| l.include?('matches') && l.include?(File.basename(temp_file_path)) },
             "expected match log, got: #{remote_info.debuggee_backlog.inspect}"
      assert remote_info.debuggee_backlog.any? { |l| l =~ /Debugger can attach via TCP\/IP/ },
             "expected port-open log, got: #{remote_info.debuggee_backlog.inspect}"
    ensure
      kill_safely(remote_info.pid, force: true) if remote_info
      remote_info&.reader_thread&.kill
      remote_info&.r&.close
      remote_info&.w&.close
    end

    # When $0 equals the exact-match string form, the port is also opened.
    def test_port_opens_when_string_equals_proctitle
      omit "no remote tests" if NO_REMOTE

      write_temp_file(strip_line_num(program))
      cmd = "#{RDBG_EXECUTABLE} -O --port=0 --open-proctitle=#{temp_file_path} -- #{temp_file_path}"

      remote_info = setup_remote_debuggee(cmd)
      assert remote_info.debuggee_backlog.any? { |l| l =~ /Debugger can attach via TCP\/IP/ },
             "expected port-open log, got: #{remote_info.debuggee_backlog.inspect}"
    ensure
      kill_safely(remote_info.pid, force: true) if remote_info
      remote_info&.reader_thread&.kill
      remote_info&.r&.close
      remote_info&.w&.close
    end

    # When $0 does not match the value, the listener returns silently without
    # opening the port. With --nonstop (no initial-suspend breakpoint), the
    # program then runs to completion unaffected by the debugger.
    def test_port_skipped_when_value_does_not_match
      omit "no remote tests" if NO_REMOTE

      program_with_print = <<~RUBY
        puts "OPEN_PROCTITLE_TEST_DONE"
      RUBY
      write_temp_file(program_with_print)

      cmd = "#{RDBG_EXECUTABLE} -O --nonstop --port=0 --open-proctitle=__NEVER_MATCHES_XYZ__ -- #{temp_file_path}"
      backlog = []
      r, _w, pid = PTY.spawn(cmd)

      Timeout.timeout(TIMEOUT_SEC) do
        while line = r.gets
          backlog << line
          break if line.include?('OPEN_PROCTITLE_TEST_DONE')
        end
      end

      assert backlog.any? { |l| l.include?('does not match') && l.include?('skipping port') },
             "expected skip log, got: #{backlog.inspect}"
      assert backlog.any? { |l| l.include?('OPEN_PROCTITLE_TEST_DONE') },
             "program should have run to completion, got: #{backlog.inspect}"
      refute backlog.any? { |l| l =~ /Debugger can attach via TCP\/IP/ },
             "port should not have been opened, got: #{backlog.inspect}"
    rescue Errno::EIO
      # PTY closed: program already exited
    ensure
      Process.kill(:TERM, pid) if pid rescue nil
      Process.waitpid(pid) if pid rescue nil
      r&.close
    end
  end
end

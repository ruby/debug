# frozen_string_literal: true

module DEBUGGER__
  module DAP_TestUtils
    class RetryBecauseCantRead < Exception
    end

    def recv_request sock, backlog
      case sock.gets
      when /Content-Length: (\d+)/
        b = sock.read(2)
        raise b.inspect unless b == "\r\n"

        l = sock.read $1.to_i
        backlog << "V<D #{l}"
        JSON.parse l, symbolize_names: true
      when nil
        nil
      when /out/, /input/
        recv_request sock, backlog
      else
        raise "unrecognized line: #{header} (#{l.nil?} bytes)"
      end
    rescue RetryBecauseCantRead
      retry
    end

    def create_protocol_msg test_info, fail_msg
      msgs = test_info.backlog
      remote_info = test_info.remote_info
      all_protocol_msg = <<~DEBUGGER_MSG.chomp
        -------------------------
        | All Protocol Messages |
        -------------------------

        #{msgs.join("\n")}
      DEBUGGER_MSG

      last_msg = msgs.reverse[0..3].map{|m|
        h = m.sub(/(D|V)(<|>)(D|V)\s/, '')
        JSON.pretty_generate(JSON.parse h)
      }.reverse.join("\n")

      last_protocol_msg = <<~DEBUGGER_MSG.chomp
        --------------------------
        | Last Protocol Messages |
        --------------------------

        #{last_msg}
      DEBUGGER_MSG

      debuggee_msg =
          <<~DEBUGGEE_MSG.chomp
            --------------------
            | Debuggee Session |
            --------------------

            > #{remote_info.debuggee_backlog.join('> ')}
          DEBUGGEE_MSG

      failure_msg = <<~FAILURE_MSG.chomp
        -------------------
        | Failure Message |
        -------------------

        #{fail_msg}
      FAILURE_MSG

      <<~MSG.chomp
        #{all_protocol_msg}

        #{last_protocol_msg}

        #{debuggee_msg}

        #{failure_msg}
      MSG
    end

    DAP_TestInfo = Struct.new(:res_backlog, :backlog, :failed_process, :reader_thread, :remote_info)

    class Detach < StandardError
    end

    def connect_to_dap_server test_info
      remote_info = test_info.remote_info
      sock = Socket.unix remote_info.sock_path
      test_info.reader_thread = Thread.new(sock, test_info) do |s, info|
        while res = recv_request(s, info.backlog)
          info.res_backlog << res
        end
      rescue Detach
      end
      sleep 0.001 while test_info.reader_thread.status != 'sleep'
      test_info.reader_thread.run
      sock
    end

    TIMEOUT_SEC = (ENV['RUBY_DEBUG_TIMEOUT_SEC'] || 10).to_i

    def run_dap_scenario program, &msgs
      begin
        write_temp_file(strip_line_num(program))

        test_info = DAP_TestInfo.new([], [])
        remote_info = test_info.remote_info = setup_unix_domain_socket_remote_debuggee
        Timeout.timeout(TIMEOUT_SEC) do
          sleep 0.001 until remote_info.debuggee_backlog.join.include? 'connection...'
        end

        res_log = test_info.res_backlog
        sock = nil
        target_msg = nil

        msgs.call.each{|msg|
          case msg[:type]
          when 'request'
            if msg[:command] == 'initialize'
              sock = connect_to_dap_server test_info
            end
            str = JSON.dump(msg)
            sock.write "Content-Length: #{str.bytesize}\r\n\r\n#{str}"
            test_info.backlog << "V>D #{str}"
          when 'response'
            target_msg = msg

            result = collect_result_from_res_log(res_log, :request_seq, msg)

            msg.delete :seq
            verify_result(result, msg, test_info)

            if msg[:command] == 'disconnect'
              res_log.clear
              test_info.reader_thread.raise Detach
              sock.close
            end
          when 'event'
            target_msg = msg

            result = collect_result_from_res_log(res_log, :event, msg)

            msg.delete :seq
            verify_result(result, msg, test_info)

            res_log.delete result
          end
        }
        flunk create_protocol_msg test_info, "Expected the debuggee program to finish" unless wait_pid remote_info.pid, 3
      rescue Timeout::Error
        flunk create_protocol_msg test_info, "TIMEOUT ERROR (#{TIMEOUT_SEC} sec) while waiting for the following response.\n#{JSON.pretty_generate target_msg}"
      ensure
        test_info.reader_thread.kill
        sock.close
        remote_info.reader_thread.kill
        remote_info.r.close
        remote_info.w.close
      end
    end

    def collect_result_from_res_log(res_log, identifier, msg)
      result = nil

      Timeout.timeout(TIMEOUT_SEC) do
        loop do
          res_log.each{|r|
            if r[identifier] == msg[identifier]
              result = r
              break
            end
          }
          break unless result.nil?

          sleep 0.01
        end
      end

      result
    end

    def verify_result(result, msg, test_info)
      expected = ResponsePattern.new.parse msg
      expected.each do |key, expected_value|
        failure_msg = FailureMessage.new{create_protocol_msg test_info, "expected:\n#{JSON.pretty_generate msg}\n\nresult:\n#{JSON.pretty_generate result}"}

        case expected_value
        when Regexp
          assert_match expected_value, result.dig(*key).to_s, failure_msg
        else
          assert_equal expected_value, result.dig(*key), failure_msg
        end
      end
    end
  end
end

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

    INITIALIZE_MSG = [
      {
        seq: 1,
        command: "initialize",
        arguments: {
          clientID: "vscode",
          clientName: "Visual Studio Code",
          adapterID: "rdbg",
          pathFormat: "path",
          linesStartAt1: true,
          columnsStartAt1: true,
          supportsVariableType: true,
          supportsVariablePaging: true,
          supportsRunInTerminalRequest: true,
          locale: "en-us",
          supportsProgressReporting: true,
          supportsInvalidatedEvent: true,
          supportsMemoryReferences: true
        },
        type: "request"
      },
      {
        seq: 2,
        command: "attach",
        arguments: {
          type: "rdbg",
          name: "Attach with rdbg",
          request: "attach",
          rdbgPath: File.expand_path('../../exe/rdbg', __dir__),
          debugPort: "/var/folders/kv/w1k6nh1x5fl7vx47b2pd005w0000gn/T/ruby-debug-sock-501/ruby-debug-naotto-8845",
          autoAttach: true,
          __sessionId: "141d9c79-3669-43ec-ac1f-e62598c5a65a"
        },
        type: "request"
      },
      {
        seq: 3,
        command: "setFunctionBreakpoints",
        arguments: {
          breakpoints: [

          ]
        },
        type: "request"
      },
      {
        seq: 4,
        command: "setExceptionBreakpoints",
        arguments: {
          filters: [

          ],
          filterOptions: [
            {
              filterId: "RuntimeError"
            }
          ]
        },
        type: "request"
      },
      {
        seq: 5,
        command: "configurationDone",
        type: "request"
      }
    ]

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
    dt = ENV['RUBY_DEBUG_DAP_TEST']
    DAP_TEST = dt == 'true' || dt == '1'

    def run_dap_scenario program, &msgs
      omit 'Tests for DAP were skipped. You can enable them with RUBY_DEBUG_DAP_TEST=1.' unless DAP_TEST

      begin
        write_temp_file(strip_line_num(program))

        test_info = DAP_TestInfo.new([], [])
        remote_info = test_info.remote_info = setup_unix_domain_socket_remote_debuggee
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
      rescue Timeout::Error
        flunk create_protocol_msg test_info, "TIMEOUT ERROR (#{TIMEOUT_SEC} sec) while waiting for the following response.\n#{JSON.pretty_generate target_msg}"
      ensure
        test_info.reader_thread.kill
        sock.close
        kill_remote_debuggee test_info
        if test_info.failed_process
          flunk create_protocol_msg test_info, "Expected the debuggee program to finish"
        end
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
      expected = ProtocolParser.new.parse msg
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

class ProtocolParser
  def initialize
    @result = []
    @keys = []
  end

  def parse objs
    objs.each{|k, v|
      parse_ k, v
      @keys.pop
    }
    @result
  end

  def parse_ k, v
    @keys << k
    case v
    when Array
      v.each.with_index{|v, i|
        parse_ i, v
        @keys.pop
      }
    when Hash
      v.each{|k, v|
        parse_ k, v
        @keys.pop
      }
    else
      @result << [@keys.dup, v]
    end
  end
end

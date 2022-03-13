# frozen_string_literal: true

module DEBUGGER__
  module CDP_TestUtils

    class Detach < StandardError
    end

    # search free port by opening server socket with port 0
    Socket.tcp_server_sockets(0).tap do |ss|
      TCPIP_PORT = ss.first.local_address.ip_port
    end.each{|s| s.close}

    RUBY = ENV['RUBY'] || RbConfig.ruby
    RDBG_EXECUTABLE = "#{RUBY} #{__dir__}/../../exe/rdbg"

    def setup_chrome_debuggee
      @remote_info = setup_remote_debuggee("#{RDBG_EXECUTABLE} -O --port=#{TCPIP_PORT} -- #{temp_file_path}")
      @remote_info.port = TCPIP_PORT

      Timeout.timeout(TIMEOUT_SEC) do
        sleep 0.001 until @remote_info.debuggee_backlog.join.include? 'connection'
      end
    rescue Timeout::Error
      flunk <<~MSG
        --------------------
        | Debuggee Session |
        --------------------
        > #{@remote_info.debuggee_backlog.join('> ')}
        TIMEOUT ERROR (#{TIMEOUT_SEC} sec)
      MSG
    end

    pt = ENV['RUBY_DEBUG_PROTOCOL_TEST']
    PROTOCOL_TEST = pt == 'true' || pt == '1'

    def connect_to_cdp_server
      omit 'Tests for CDP were skipped. You can enable them with RUBY_DEBUG_PROTOCOL_TEST=1.' unless PROTOCOL_TEST

      ENV['RUBY_DEBUG_TEST_MODE'] = 'true'

      sock = Socket.tcp HOST, @remote_info.port
      Timeout.timeout(TIMEOUT_SEC) do
        sleep 0.001 until @remote_info.debuggee_backlog.join.include? 'Connected'
      end
      @web_sock = WebSocketClient.new sock
      @web_sock.handshake @remote_info.port, '/'
      @reader_thread = Thread.new do
        Thread.current.abort_on_exception = true
        while res = @web_sock.extract_data
          str = JSON.dump res
          @backlog << "C<D #{str}"
          @res_backlog << JSON.parse(str, symbolize_names: true) # Because hash's keys of `res` are string, we need to convert them to symbol.
        end
      end
      sleep 0.001 while @reader_thread.status != 'sleep'
      @reader_thread.run
    rescue Timeout::Error
      flunk <<~MSG
        --------------------
        | Debuggee Session |
        --------------------
        > #{remote_info.debuggee_backlog.join('> ')}
        TIMEOUT ERROR (#{TIMEOUT_SEC} sec)
      MSG
    end

    TIMEOUT_SEC = (ENV['RUBY_DEBUG_TIMEOUT_SEC'] || 10).to_i
    HOST = '127.0.0.1'

    def run_cdp_scenario program, &msgs
      ENV['RUBY_DEBUG_TEST_UI'] = 'chrome'

      program = program.delete_suffix "\n"
      write_temp_file(strip_line_num(program))

      setup_chrome_debuggee
      connect_to_cdp_server
      exchange_cdp_message msgs
    rescue Detach
    end

    def exchange_cdp_message msgs
      @res_backlog = []
      @backlog = []
      target_msg = nil
      obj_map = {}
      current_frame = nil
      evaluateOnCallFrameId = nil
      expression = nil
      getProperties_id = nil
      msgs.call.each{|msg|
        case
        # request
        when msg.key?(:method) && msg.key?(:id)
          case msg[:method]
          when 'Runtime.getProperties'
            o_id = msg.dig(:params, :objectId)
            msg[:params][:objectId] = obj_map[o_id]
            getProperties_id = msg[:id]
          when 'Debugger.evaluateOnCallFrame'
            callFrameId = current_frame[:callFrameId]
            msg[:params][:callFrameId] = callFrameId
            expression = msg.dig(:params, :expression)
            evaluateOnCallFrameId = msg[:id]
          end

          @web_sock.send(msg)
          str = JSON.dump msg
          @backlog << "C>D #{str}"
        # response
        when msg.key?(:id) && (msg.key?(:result) || msg.key?(:error))
          target_msg = msg

          result, _ = find_result(:id, msg)
          case result[:id]
          when evaluateOnCallFrameId
            o_id = result.dig(:result, :result, :objectId)
            obj_map[expression] = o_id
          when getProperties_id
            rs = result.dig(:result, :result)
            rs.each{|r|
              o_id = r.dig(:value, :objectId)
              v = r.dig(:value, :value)
              obj_map[v] = o_id
            }
            internalProperties = result.dig(:result, :internalProperties)
            internalProperties.each{|p|
              o_id = p.dig(:value, :objectId)
              description = p.dig(:value, :description)
              obj_map[description] = o_id
            } unless internalProperties.nil?
          end

          assert_result msg, result
        # event
        when msg.key?(:method)
          target_msg = msg

          result, result_idx = find_result(:method, msg)
          case result[:method]
          when 'Debugger.paused'
            frames = result.dig(:params, :callFrames)
            current_frame = frames.first
            frames.each_with_index{|frame, idx|
              frame[:scopeChain].each{|scope|
                o_id = scope.dig(:object, :objectId)
                key = "#{idx}:#{scope[:type]}"
                obj_map[key] = o_id
              }
            }
          end

          assert_result msg, result
          @res_backlog.delete_at result_idx
        else
          raise "Unknown message #{msg}"
        end
      }
      flunk create_protocol_message "Expected the debuggee program to finish" unless wait_pid @remote_info.pid, TIMEOUT_SEC
    rescue Timeout::Error
      flunk create_protocol_message"TIMEOUT ERROR (#{TIMEOUT_SEC} sec) while waiting for the following response.\n#{JSON.pretty_generate target_msg}"
    ensure
      @reader_thread.kill
      @web_sock.cleanup
      @remote_info.reader_thread.kill
      @remote_info.r.close
      @remote_info.w.close
    end

    # FIXME: Commonalize this method.
    def find_result(identifier, msg)
      result = nil
      result_idx = nil

      Timeout.timeout(TIMEOUT_SEC) do
        loop do
          @res_backlog.each_with_index{|r, i|
            if r[identifier] == msg[identifier]
              result = r
              result_idx = i
              break
            end
          }
          break unless result.nil?

          sleep 0.01
        end
      end

      [result, result_idx]
    end

    # FIXME: Commonalize this method.
    def assert_result(expected, actual)
      pattern = ResponsePattern.new.parse expected
      pattern.each do |key, expected_value|
        msg = <<~MSG
          expected:
          #{JSON.pretty_generate expected}

          actual:
          #{JSON.pretty_generate actual}
        MSG
        failure_msg = FailureMessage.new{create_protocol_message msg}

        case expected_value
        when Regexp
          assert_match expected_value, actual.dig(*key).to_s, failure_msg
        else
          assert_equal expected_value, actual.dig(*key), failure_msg
        end
      end
    end
  end
end

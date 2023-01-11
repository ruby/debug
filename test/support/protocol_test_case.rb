require 'net/http'
require 'uri'
require 'digest/sha1'
require 'base64'

require_relative 'test_case'
require_relative 'dap_utils'
require_relative 'cdp_utils'

module DEBUGGER__
  class ProtocolTestCase < TestCase
    include DAP_TestUtils
    include CDP_TestUtils

    class Detach < StandardError
    end

    DAP_JSON_PATH = "#{__dir__}/../../debugAdapterProtocol.json"
    CDP_JSON_PATH = "#{__dir__}/../../chromeDevToolsProtocol.json"

    begin
      require 'json-schema'
      if File.exist? DAP_JSON_PATH
        json = File.read(DAP_JSON_PATH)
      else
        json = Net::HTTP.get(URI.parse('https://microsoft.github.io/debug-adapter-protocol/debugAdapterProtocol.json'))
        File.write DAP_JSON_PATH, json
      end
      DAP_HASH = JSON.parse(json, symbolize_names: true)
    rescue LoadError
    end

    if File.exist? CDP_JSON_PATH
      json = File.read(CDP_JSON_PATH)
    else
      json = Net::HTTP.get(URI.parse('https://raw.githubusercontent.com/ChromeDevTools/devtools-protocol/master/json/js_protocol.json'))
      File.write CDP_JSON_PATH, json
    end
    CDP_HASH = JSON.parse(json, symbolize_names: true)

    # API

    def run_protocol_scenario program, dap: true, cdp: true, &scenario
      Timeout.timeout(30) do
        write_temp_file(strip_line_num(program))
        execute_dap_scenario scenario if dap
        execute_cdp_scenario scenario if cdp

        check_line_num!(program)
      end
    end

    def attach_to_dap_server
      @sock = Socket.unix @remote_info.sock_path
      @seq = 1
      @reader_thread = Thread.new do
        while res = recv_response
          @queue.push res
        end
      rescue Detach
      end
      sleep 0.001 while @reader_thread.status != 'sleep'
      @reader_thread.run
      INITIALIZE_DAP_MSGS.each{|msg| send(**msg)}
    end

    def attach_to_cdp_server
      body = get_request HOST, @remote_info.port, '/json'
      Timeout.timeout(TIMEOUT_SEC) do
        sleep 0.001 until @remote_info.debuggee_backlog.join.include? 'Disconnected.'
      end

      sock = Socket.tcp HOST, @remote_info.port
      uuid = body[0][:id]

      Timeout.timeout(TIMEOUT_SEC) do
        sleep 0.001 until @remote_info.debuggee_backlog.join.match?(/Disconnected\.\R.*Connected/)
      end

      @web_sock = WebSocketClient.new sock
      @web_sock.handshake @remote_info.port, uuid
      @id = 1
      @reader_thread = Thread.new do
        while res = @web_sock.extract_data
          @queue.push res
        end
      rescue Detach
      end
      sleep 0.001 while @reader_thread.status != 'sleep'
      @reader_thread.run
      INITIALIZE_CDP_MSGS.each{|msg| send(**msg)}
    end

    def req_dap_disconnect(terminate_debuggee:)
      send_dap_request 'disconnect', restart: false, terminateDebuggee: terminate_debuggee
      close_reader
    end

    def req_cdp_disconnect
      @web_sock.send_close_connection
      close_reader
    end

    def req_add_breakpoint lineno, path: temp_file_path, cond: nil
      case get_target_ui
      when 'vscode'
        @bps << [path, lineno, cond]
        req_set_breakpoints_on_dap
      when 'chrome'
        escaped = Regexp.escape File.realpath path
        regexp = "#{escaped}|file://#{escaped}"
        res = send_cdp_request 'Debugger.setBreakpointByUrl',
                      lineNumber: lineno - 1,
                      urlRegex: regexp,
                      columnNumber: 0,
                      condition: cond
        @bps << res.dig(:result, :breakpointId)
      end
    end

    def req_delete_breakpoint bpnum
      case get_target_ui
      when 'vscode'
        @bps.delete_at bpnum
        req_set_breakpoints_on_dap
      when 'chrome'
        b_id = @bps.delete_at bpnum
        send_cdp_request 'Debugger.removeBreakpoint', breakpointId: b_id
      end
    end

    def req_continue
      case get_target_ui
      when 'vscode'
        send_dap_request 'continue', threadId: 1
      when 'chrome'
        send_cdp_request 'Debugger.resume'
        res = find_response :method, 'Debugger.paused', 'C<D'
        @crt_frames = res.dig(:params, :callFrames)
      end
    end

    def req_step
      case get_target_ui
      when 'vscode'
        send_dap_request 'stepIn', threadId: 1
      when 'chrome'
        send_cdp_request 'Debugger.stepInto'
        res = find_response :method, 'Debugger.paused', 'C<D'
        @crt_frames = res.dig(:params, :callFrames)
      end
    end

    def req_next
      case get_target_ui
      when 'vscode'
        send_dap_request 'next', threadId: 1
      when 'chrome'
        send_cdp_request 'Debugger.stepOver'
        res = find_response :method, 'Debugger.paused', 'C<D'
        @crt_frames = res.dig(:params, :callFrames)
      end
    end

    def req_finish
      case get_target_ui
      when 'vscode'
        send_dap_request 'stepOut', threadId: 1
      when 'chrome'
        send_cdp_request 'Debugger.stepOut'
        res = find_response :method, 'Debugger.paused', 'C<D'
        @crt_frames = res.dig(:params, :callFrames)
      end
    end

    def req_set_exception_breakpoints(breakpoints)
      case get_target_ui
      when 'vscode'
        filter_options = breakpoints.map do |bp|
          filter_option = { filterId: bp[:name] }
          filter_option[:condition] = bp[:condition] if bp[:condition]
          filter_option
        end

        send_dap_request 'setExceptionBreakpoints', filters: [], filterOptions: filter_options
      when 'chrome'
        send_cdp_request 'Debugger.setPauseOnExceptions', state: 'all'
      end
    end

    def req_step_back
      case get_target_ui
      when 'vscode'
        send_dap_request 'stepBack', threadId: 1
      end
    end

    def req_terminate_debuggee
      case get_target_ui
      when 'vscode'
        send_dap_request 'terminate'
      when 'chrome'
        send_cdp_request 'Runtime.terminateExecution'
      end

      close_reader
    end

    def gather_variables(frame_idx: 0, type: "locals")
      case get_target_ui
      when 'vscode'
        # get frameId
        res = send_dap_request 'stackTrace',
                      threadId: 1,
                      startFrame: 0,
                      levels: 20
        f_id = res.dig(:body, :stackFrames, frame_idx, :id)

        # get variablesReference
        res = send_dap_request 'scopes', frameId: f_id

        locals_scope = res.dig(:body, :scopes).find { |d| d[:presentationHint] == type }
        locals_reference = locals_scope[:variablesReference]

        # get variables
        res = send_dap_request 'variables', variablesReference: locals_reference
        res.dig(:body, :variables).map { |loc| { name: loc[:name], value: loc[:value], type: loc[:type], variablesReference: loc[:variablesReference] } }
      when 'chrome'
        current_frame = @crt_frames.first
        locals_scope = current_frame[:scopeChain].find { |f| f[:type] == type }
        object_id = locals_scope.dig(:object, :objectId)

        res = send_cdp_request "Runtime.getProperties", objectId: object_id

        res.dig(:result, :result).map do |loc|
          type = loc.dig(:value, :className) || loc.dig(:value, :type).capitalize # TODO: sync this with get_ruby_type

          { name: loc[:name], value: loc.dig(:value, :description), type: type }
        end
      end
    end

    def assert_locals_result expected, frame_idx: 0
      case get_target_ui
      when 'vscode'
        actual_locals = gather_dap_variables(frame_idx: frame_idx, type: "locals")

        expected.each do |exp|
          if exp[:type] == "String"
            exp[:value] = exp[:value].inspect
          end
        end
      when 'chrome'
        actual_locals = gather_variables(type: "local")
      end

      failure_msg = FailureMessage.new{create_protocol_message "result:\n#{JSON.pretty_generate res}"}

      actual_locals = actual_locals.sort_by { |h| h[:name] }
      expected = expected.sort_by { |h| h[:name] }

      expected.each_with_index do |expect, index|
        actual = actual_locals[index]
        assert_equal(expect[:name], actual[:name], failure_msg)
        assert_equal(expect[:type], actual[:type], failure_msg)

        if expect[:value].is_a?(Regexp)
          assert_match(expect[:value], actual[:value], failure_msg)
        else
          assert_equal(expect[:value], actual[:value], failure_msg)
        end
      end
    end

    def assert_threads_result(expected_names)
      case get_target_ui
      when 'vscode'
        res = send_dap_request 'threads'
        failure_msg = FailureMessage.new{create_protocol_message "result:\n#{JSON.pretty_generate res}."}

        threads = res.dig(:body, :threads)

        assert_equal expected_names.count, threads.count, failure_msg

        thread_names = threads.map { |t| t[:name] }

        expected_names.each do |expected|
          thread_names.reject! do |name|
            name.match?(expected)
          end
        end

        failure_msg = FailureMessage.new{create_protocol_message "result:\n#{JSON.pretty_generate res}.\nExpect all thread names to be matched. Unmatched threads:"}
        assert_equal [], thread_names, failure_msg
      end
    end

    def assert_hover_result expected, expression, frame_idx: 0
      case get_target_ui
      when 'vscode'
        assert_eval_result 'hover', expression, expected, frame_idx
      when 'chrome'
        assert_eval_result 'popover', expression, expected, frame_idx
      end
    end

    def assert_repl_result expected,  expression, frame_idx: 0
      case get_target_ui
      when 'vscode'
        assert_eval_result 'repl', expression, expected, frame_idx
      when 'chrome'
        assert_eval_result 'console', expression, expected, frame_idx
      end
    end

    def assert_watch_result expected,  expression, frame_idx: 0
      case get_target_ui
      when 'vscode'
        assert_eval_result 'watch', expression, expected, frame_idx
      when 'chrome'
        assert_eval_result 'watch-group', expression, expected, frame_idx
      end
    end

    # Not API

    def execute_dap_scenario scenario
      ENV['RUBY_DEBUG_TEST_UI'] = 'vscode'

      # TestInfo is defined to use kill_remote_debuggee method.
      test_info = TestInfo.new

      @remote_info = test_info.remote_info = setup_unix_domain_socket_remote_debuggee
      Timeout.timeout(TIMEOUT_SEC) do
        sleep 0.001 until @remote_info.debuggee_backlog.join.include? 'connection...'
      end

      @bps = [] # [[path, lineno, condition], ...]
      @res_backlog = []
      @queue = Queue.new
      @backlog = []

      attach_to_dap_server
      scenario.call
    rescue Test::Unit::AssertionFailedError => e
      is_assertion_failure = true
      raise e
    ensure
      kill_remote_debuggee test_info
      if test_info.failed_process && !is_assertion_failure
        flunk create_protocol_message "Expected the debuggee program to finish"
      end
      # Because the debuggee may be terminated by executing the following operations, we need to run them after `kill_remote_debuggee` method.
      @reader_thread&.kill
      @sock&.close
    end

    def execute_cdp_scenario_ scenario
      ENV['RUBY_DEBUG_TEST_UI'] = 'chrome'

      # TestInfo is defined to use kill_remote_debuggee method.
      test_info = TestInfo.new

      @web_sock = nil
      @remote_info = test_info.remote_info = setup_tcpip_remote_debuggee
      Timeout.timeout(TIMEOUT_SEC) do
        sleep 0.001 until @remote_info.debuggee_backlog.join.include? @remote_info.port.to_s
      end

      @res_backlog = []
      @bps = [] # [b_id, ...]
      @queue = Queue.new
      @backlog = []

      attach_to_cdp_server
      res = find_response :method, 'Debugger.paused', 'C<D'
      @crt_frames = res.dig(:params, :callFrames)
      scenario.call
    rescue Test::Unit::AssertionFailedError => e
      is_assertion_failure = true
      raise e
    ensure
      kill_remote_debuggee test_info
      if test_info.failed_process && !is_assertion_failure
        flunk create_protocol_message "Expected the debuggee program to finish"
      end
      # Because the debuggee may be terminated by executing the following operations, we need to run them after `kill_remote_debuggee` method.
      @reader_thread&.kill
      @web_sock&.close
    end

    def execute_cdp_scenario scenario
      retry_cnt = 0
      begin
        execute_cdp_scenario_ scenario
      rescue Errno::ECONNREFUSED
        if (retry_cnt += 1) > 10
          STDERR.puts "retry #{retry_cnt} but can not connect!"
          raise
        end

        STDERR.puts "retry (#{retry_cnt}) connecting..."

        sleep 0.3
        retry
      end
    end

    def req_disconnect
      case get_target_ui
      when 'vscode'
        send_dap_request 'disconnect',
                      restart: false,
                      terminateDebuggee: false
      when 'chrome'
        @web_sock.send_close_connection
      end

      close_reader
    end

    def req_set_breakpoints_on_dap
      bps_map = {temp_file_path => []}
      @bps.each{|tar_path, tar_lineno, condition|
        if bps_map[tar_path].nil?
          bps_map[tar_path] = []
        end
        bps_map[tar_path] << [tar_lineno, condition]
      }
      bps_map.each{|tar_path, bps|
        send_dap_request 'setBreakpoints',
                      source: {
                        name: tar_path,
                        path: tar_path,
                        sourceReference: 0
                      },
                      breakpoints: bps.map{|lineno, condition|
                        {
                          line: lineno,
                          condition: condition
                        }
                      }
      }
    end

    def close_reader
      @reader_thread.raise Detach

      case get_target_ui
      when 'vscode'
        @sock.close
      when 'chrome'
        @web_sock.close
      end
    end

    HOST = '127.0.0.1'

    JAVASCRIPT_TYPE_TO_CLASS_MAPS = {
      'string' => String,
      'number' => Integer,
      'boolean' => [TrueClass, FalseClass],
      'symbol' => Symbol
    }

    def assert_eval_result context, expression, expected, frame_idx
      case get_target_ui
      when 'vscode'
        res = send_dap_request 'stackTrace',
                      threadId: 1,
                      startFrame: 0,
                      levels: 20
        f_id = res.dig(:body, :stackFrames, frame_idx, :id)
        res = send_dap_request 'evaluate',
                      expression: expression,
                      frameId: f_id,
                      context: context

        failure_msg = FailureMessage.new{create_protocol_message "result:\n#{JSON.pretty_generate res}"}
        if expected[:type] == 'String'
          expected[:value] = expected[:value].inspect
        end

        result_type = res.dig(:body, :type)
        assert_equal expected[:type], result_type, failure_msg

        result_val = res.dig(:body, :result)
        if expected[:value].is_a? Regexp
          assert_match expected[:value], result_val, failure_msg
        else
          assert_equal expected[:value], result_val, failure_msg
        end
      when 'chrome'
        f_id = @crt_frames.dig(frame_idx, :callFrameId)
        res = send_cdp_request 'Debugger.evaluateOnCallFrame',
                      expression: expression,
                      callFrameId: f_id,
                      objectGroup: context

        failure_msg = FailureMessage.new{create_protocol_message "result:\n#{JSON.pretty_generate res}"}

        cl = res.dig(:result, :result, :className) || JAVASCRIPT_TYPE_TO_CLASS_MAPS[res.dig(:result, :result, :type)].inspect
        result_type = Array cl
        assert_include result_type, expected[:type], failure_msg

        result_val = res.dig(:result, :result, :description)
        if expected[:value].is_a? Regexp
          assert_match expected[:value], result_val, failure_msg
        else
          assert_equal expected[:value], result_val, failure_msg
        end
      end
    end

    def send_request command, **kw
      case get_target_ui
      when 'vscode'
        send type: 'request',
            command: command,
            arguments: kw
      when 'chrome'
        send method: command,
            params: kw
      end
    rescue StandardError => e
      flunk create_protocol_message "Failed to send request because of #{e.class.name}: #{e.message}"
    end

    def send_dap_request command, **kw
      send_request command, **kw

      # TODO: Return the response for "stepBack"
      return if command == "stepBack"

      res = find_crt_dap_response

      command_name = command[0].upcase + command[1..-1]
      assert_dap_response("#{command_name}Response".to_sym, res)

      res
    end

    def send_cdp_request command, **kw
      send_request command, **kw
      res = find_crt_cdp_response
      assert_cdp_response(command, res)
      res
    end

    def send **kw
      case get_target_ui
      when 'vscode'
        kw[:seq] = @seq += 1
        str = JSON.dump(kw)
        @sock.write "Content-Length: #{str.bytesize}\r\n\r\n#{str}"
        @backlog << "V>D #{str}"
      when 'chrome'
        kw[:id] = @id += 1
        @web_sock.send kw
        str = JSON.dump kw
        @backlog << "C>D #{str}"
      end
    end

    TIMEOUT_SEC = (ENV['RUBY_DEBUG_TIMEOUT_SEC'] || 10).to_i

    def assert_dap_response expected_def, result_res
      return unless defined? DAP_HASH

      err = nil
      begin
        JSON::Validator.validate!(DAP_HASH, result_res, :fragment => "#/definitions/#{expected_def}/allOf/1")
      rescue JSON::Schema::ValidationError => e
        err = e.message
      end
      if err
        fail_msg = <<~MSG
          result:
          #{JSON.pretty_generate result_res}

          #{err}
        MSG
        flunk create_protocol_message fail_msg
      else
        assert true
      end
    end

    def assert_cdp_response expected_def, result_res
      domain, cmd = expected_def.split(".")
      begin
        CDP_Validator.new.validate(result_res, domain, cmd)
      rescue CDP_Validator::ValidationError => e
        err = e.message
      end
      if err
        fail_msg = <<~MSG
          result:
          #{JSON.pretty_generate result_res}

          #{err}
        MSG
        flunk create_protocol_message fail_msg
      else
        assert true
      end
    end

    def find_crt_dap_response
      find_response :request_seq, @seq, 'V<D'
    end

    def find_crt_cdp_response
      find_response :id, @id, 'C<D'
    end

    def find_response key, target, direction
      Timeout.timeout(TIMEOUT_SEC) do
        loop do
          res = @queue.pop
          str = JSON.dump(res)
          @backlog << "#{direction} #{str}"
          if res[key] == target
            return res
          end
        end
      end
    rescue Timeout::Error
      flunk create_protocol_message "TIMEOUT ERROR (#{TIMEOUT_SEC} sec) while waiting: #{key} #{target}"
    end

    # FIXME: Commonalize this method.
    def recv_response
      case  header = @sock.gets
      when /Content-Length: (\d+)/
        b = @sock.read(2)
        raise b.inspect unless b == "\r\n"

        l = @sock.read $1.to_i
        JSON.parse l, symbolize_names: true
      when nil
        nil
      when /out/, /input/
        recv_response
      else
        raise "unrecognized line: #{header}"
      end
    end

    class CDP_Validator
      class ValidationError < Exception
      end

      JSON_TYPE_TO_CLASS_MAPS = {
        'string' => String,
        'integer' => Integer,
        'boolean' => [TrueClass, FalseClass],
        'object' => Hash,
        'array' => Array,
        'any' => Object
      }

      def validate res, domain, command
        @seen = []
        pattern = get_cmd_pattern(domain, command)
        raise ValidationError, "Expected to include `result` in responses" if res[:result].nil?
        validate_ res[:result], pattern[:returns]
        true
      end

      def validate_ res, props
        return if props.nil?

        props.each{|prop|
          name = prop[:name].to_sym
          if property = res[name]
            cs = Array JSON_TYPE_TO_CLASS_MAPS[prop[:type]]
            unless cs.any?{|c| property.is_a? c}
              raise ValidationError, "Expected property `#{name}` to be kind of #{cs.join}, but it was #{property.class}"
            end
            validate_ property, prop[:properties]
          else
            raise ValidationError, "Expected to include `#{name}` in responses" unless prop.fetch(:optional, false)
          end
        }
      end

      def get_cmd_pattern domain, command
        cmd = nil
        # FIXME: Commonalize this part.
        CDP_HASH[:domains].each{|d|
          if d[:domain] == domain
            d[:commands].each{|c|
              if c[:name] == command
                cmd = c
                break
              end
            }
          end
        }
        if returns = cmd[:returns]
          returns.each{|ret|
            if ref = ret[:$ref]
              ret.merge!(collect_ref(domain, ref))
            elsif ref = ret.dig(:items, :$ref)
              ret[:items].merge!(collect_ref(domain, ref))
            end
          }
        end
        cmd
      end

      def collect_ref crt_domain, ref
        if ref.include? "."
          tar_domain, tar_cmd = ref.split(".")
        else
          tar_domain = crt_domain
          tar_cmd = ref
        end
        return {} if @seen.include?(tar_domain + '.' + tar_cmd)

        type = nil
        # FIXME: Commonalize this part.
        CDP_HASH[:domains].each{|domain|
          if domain[:domain] == tar_domain
            domain[:types].each{|t|
              if t[:id] == tar_cmd
                type = t
                break
              end
            }
          end
        }
        @seen << tar_domain + '.' + type[:id]
        if props = type[:properties]
          props.each{|prop|
            if ref = prop[:$ref]
              prop.merge!(collect_ref(tar_domain, ref))
            elsif ref = prop.dig(:items, :$ref)
              prop[:items].merge!(collect_ref(tar_domain, ref))
            end
          }
        end
        type
      end
    end

    def create_protocol_message fail_msg
      all_protocol_msg = <<~DEBUGGER_MSG.chomp
        -------------------------
        | All Protocol Messages |
        -------------------------

        #{@backlog.join("\n")}
      DEBUGGER_MSG

      case get_target_ui
      when 'vscode'
        pattern = /(D|V)(<|>)(D|V)\s/
      when 'chrome'
        pattern = /(D|C)(<|>)(D|C)\s/
      end

      last_msg = @backlog.last(3).map{|log|
        json = log.sub(pattern, '')
        JSON.pretty_generate(JSON.parse json)
      }.join("\n")

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

            > #{@remote_info.debuggee_backlog.join('> ')}
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
  end

  class WebSocketClient
    class Frame
      attr_reader :binary

      def initialize
        @binary = ''.b
      end

      def << obj
        case obj
        when String
          @binary << obj.b
        when Enumerable
          obj.each{|e| self << e}
        end
      end

      def char bytes
        @binary << bytes
      end

      def ulonglong bytes
        @binary << [bytes].pack('Q>')
      end

      def uint16 bytes
        @binary << [bytes].pack('n*')
      end
    end

    def initialize s
      @sock = s
    end

    def handshake port, uuid
      key = SecureRandom.hex(11)
      @sock.print "GET /#{uuid} HTTP/1.1\r\nHost: 127.0.0.1:#{port}\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: #{key}==\r\n\r\n"
      server_key = get_server_key

      correct_key = Base64.strict_encode64 Digest::SHA1.digest "#{key}==258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
      raise "The Sec-WebSocket-Accept value: #{$1} is not valid" unless server_key == correct_key
    end

    def send msg
      msg = JSON.generate(msg)
      frame = Frame.new
      fin = 0b10000000
      opcode = 0b00000001
      frame.char fin + opcode

      mask = 0b10000000 # A client must mask all frames in a WebSocket Protocol.
      bytesize = msg.bytesize
      if bytesize < 126
        payload_len = bytesize
        frame.char mask + payload_len
      elsif bytesize < 2 ** 16
        payload_len = 0b01111110
        frame.char mask + payload_len
        frame.uint16 bytesize
      elsif bytesize < 2 ** 64
        payload_len = 0b01111111
        frame.char mask + payload_len
        frame.ulonglong bytesize
      else
        raise 'Bytesize is too big.'
      end

      masking_key = 4.times.map{
        key = rand(1..255)
        frame.char key
        key
      }
      msg.bytes.each_with_index do |b, i|
        frame.char(b ^ masking_key[i % 4])
      end

      @sock.print frame.binary
    end

    def extract_data
      first_group = @sock.getbyte
      fin = first_group
      return nil if fin.nil?
      raise 'Unsupported' if fin & 0b10000000 != 128
      opcode = first_group & 0b00001111
      raise "Unsupported: #{opcode}" unless opcode == 1

      second_group = @sock.getbyte
      mask = second_group & 0b10000000 == 128
      raise 'The server must not mask any frames' if mask
      payload_len = second_group & 0b01111111
      # TODO: Support other payload_lengths
      if payload_len == 126
        payload_len = @sock.read(2).unpack('n*')[0]
      end

      JSON.parse @sock.read(payload_len), symbolize_names: true
    end

    def send_close_connection
      frame = []
      fin = 0b10000000
      opcode = 0b00001000
      frame << fin + opcode

      @sock.print frame.pack 'c*'
    end

    def close
      @sock.close
    end

    private

    def get_server_key
      Timeout.timeout(ProtocolTestCase::TIMEOUT_SEC) do
        loop do
          res = @sock.readpartial 4092
          if res.match(/^Sec-WebSocket-Accept: (.*)\r\n/)
            return $1
          end
        end
      end
    end
  end

  # When constant variables are referred from modules, they have to be defined outside the class.
  INITIALIZE_DAP_MSGS = [
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

  INITIALIZE_CDP_MSGS = [
    {
      id: 1,
      method: "Runtime.enable",
      params: {
      }
    },
    {
      id: 2,
      method: "Debugger.enable",
      params: {
        maxScriptsCacheSize: 10000000
      }
    },
    {
      id: 3,
      method: "Debugger.setPauseOnExceptions",
      params: {
        state: "none"
      }
    },
    {
      id: 4,
      method: "Debugger.setAsyncCallStackDepth",
      params: {
        maxDepth: 32
      }
    },
    {
      id: 5,
      method: "Profiler.enable",
      params: {
      }
    },
    {
      id: 6,
      method: "Debugger.setBlackboxPatterns",
      params: {
        patterns: [

        ]
      }
    },
    {
      id: 7,
      method: "Runtime.runIfWaitingForDebugger",
      params: {
      }
    }
  ]

  class ResponsePattern
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
end

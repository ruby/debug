# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require 'digest/sha1'
require 'base64'

module DEBUGGER__
  module Protocol_TestUtils
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

    pt = ENV['RUBY_DEBUG_PROTOCOL_TEST']
    PROTOCOL_TEST = pt == 'true' || pt == '1'

    unless PROTOCOL_TEST
      warn 'Tests for CDP and DAP were skipped. You can enable them with RUBY_DEBUG_PROTOCOL_TEST=1.'
    end

    # API

    def run_protocol_scenario program, dap: true, cdp: true, &scenario
      return unless PROTOCOL_TEST

      write_temp_file(strip_line_num(program))
      execute_dap_scenario scenario if dap
      execute_cdp_scenario scenario if cdp

      check_line_num!(program)
    end

    def req_add_breakpoint lineno, path: temp_file_path, cond: nil
      case ENV['RUBY_DEBUG_TEST_UI']
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
      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        @bps.delete_at bpnum
        req_set_breakpoints_on_dap
      when 'chrome'
        b_id = @bps.delete_at bpnum
        send_cdp_request 'Debugger.removeBreakpoint', breakpointId: b_id
      end
    end

    def req_continue
      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        send_dap_request 'continue', threadId: 1
      when 'chrome'
        send_cdp_request 'Debugger.resume'
        res = find_response :method, 'Debugger.paused', 'C<D'
        @crt_frames = res.dig(:params, :callFrames)
      end
    end

    def req_step
      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        send_dap_request 'stepIn', threadId: 1
      when 'chrome'
        send_cdp_request 'Debugger.stepInto'
        res = find_response :method, 'Debugger.paused', 'C<D'
        @crt_frames = res.dig(:params, :callFrames)
      end
    end

    def req_next
      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        send_dap_request 'next', threadId: 1
      when 'chrome'
        send_cdp_request 'Debugger.stepOver'
        res = find_response :method, 'Debugger.paused', 'C<D'
        @crt_frames = res.dig(:params, :callFrames)
      end
    end

    def req_finish
      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        send_dap_request 'stepOut', threadId: 1
      when 'chrome'
        send_cdp_request 'Debugger.stepOut'
        res = find_response :method, 'Debugger.paused', 'C<D'
        @crt_frames = res.dig(:params, :callFrames)
      end
    end

    def req_set_exception_breakpoints
      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        send_dap_request 'setExceptionBreakpoints',
                      filters: [],
                      filterOptions: [
                        {
                          filterId: 'RuntimeError'
                        }
                      ]
      when 'chrome'
        send_cdp_request 'Debugger.setPauseOnExceptions', state: 'all'
      end
    end

    def req_step_back
      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        send_dap_request 'stepBack', threadId: 1
      end
    end

    def req_terminate_debuggee
      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        send_dap_request 'terminate'
      when 'chrome'
        send_cdp_request 'Runtime.terminateExecution'
      end

      cleanup_reader
    end

    def assert_reattach
      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        req_disconnect
        attach_to_dap_server
        res = find_crt_dap_response
        result_cmd = res.dig(:command)
        assert_equal 'configurationDone', result_cmd
      when 'chrome'
        req_disconnect
        attach_to_cdp_server
      end
    end

    def assert_locals_result expected, frame_idx: 0
      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        # get frameId
        res = send_dap_request 'stackTrace',
                      threadId: 1,
                      startFrame: 0,
                      levels: 20
        f_id = res.dig(:body, :stackFrames, frame_idx, :id)

        # get variablesReference
        res = send_dap_request 'scopes', frameId: f_id

        locals_scope = res.dig(:body, :scopes).find { |d| d[:presentationHint] == "locals" }
        locals_reference = locals_scope[:variablesReference]

        # get variables
        res = send_dap_request 'variables', variablesReference: locals_reference

        expected.each do |exp|
          if exp[:type] == "String"
            exp[:value] = exp[:value].inspect
          end
        end

        actual_locals = res.dig(:body, :variables).map { |loc| { name: loc[:name], value: loc[:value], type: loc[:type] } }
      when 'chrome'
        current_frame = @crt_frames.first
        locals_scope = current_frame[:scopeChain].find { |f| f[:type] == "local" }
        object_id = locals_scope.dig(:object, :objectId)

        res = send_cdp_request "Runtime.getProperties", objectId: object_id

        actual_locals = res.dig(:result, :result).map do |loc|
          type = loc.dig(:value, :className) || loc.dig(:value, :type).capitalize # TODO: sync this with get_ruby_type

          { name: loc[:name], value: loc.dig(:value, :description), type: type }
        end
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
      case ENV['RUBY_DEBUG_TEST_UI']
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

    def assert_hover_result expected,  expression: nil, frame_idx: 0
      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        assert_eval_result 'hover', expression, expected, frame_idx
      when 'chrome'
        assert_eval_result 'popover', expression, expected, frame_idx
      end
    end

    def assert_repl_result expected,  expression: nil, frame_idx: 0
      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        assert_eval_result 'repl', expression, expected, frame_idx
      when 'chrome'
        assert_eval_result 'console', expression, expected, frame_idx
      end
    end

    def assert_watch_result expected,  expression: nil, frame_idx: 0
      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        assert_eval_result 'watch', expression, expected, frame_idx
      when 'chrome'
        assert_eval_result 'watch-group', expression, expected, frame_idx
      end
    end

    # Not API

    def execute_dap_scenario scenario
      ENV['RUBY_DEBUG_TEST_UI'] = 'vscode'

      @remote_info = setup_unix_domain_socket_remote_debuggee
      Timeout.timeout(TIMEOUT_SEC) do
        sleep 0.001 until @remote_info.debuggee_backlog.join.include? 'connection...'
      end

      @bps = [] # [[path, lineno, condition], ...]
      @res_backlog = []
      @queue = Queue.new
      @backlog = []

      attach_to_dap_server
      scenario.call

      flunk create_protocol_message "Expected the debuggee program to finish" unless wait_pid @remote_info.pid, TIMEOUT_SEC
    ensure
      @reader_thread.kill
      @sock.close if @sock
      @remote_info.reader_thread.kill
      @remote_info.r.close
      @remote_info.w.close
    end

    def execute_cdp_scenario scenario
      ENV['RUBY_DEBUG_TEST_UI'] = 'chrome'

      @remote_info = setup_tcpip_remote_debuggee
      Timeout.timeout(TIMEOUT_SEC) do
        sleep 0.001 until @remote_info.debuggee_backlog.join.include? @remote_info.port.to_s
      end

      @res_backlog = []
      @bps = [] # [b_id, ...]
      @queue = Queue.new
      @backlog = []

      attach_to_cdp_server
      scenario.call

      flunk create_protocol_message "Expected the debuggee program to finish" unless wait_pid @remote_info.pid, TIMEOUT_SEC
    ensure
      @reader_thread.kill
      @web_sock.cleanup if @web_sock
      @remote_info.reader_thread.kill
      @remote_info.r.close
      @remote_info.w.close
    end

    def req_disconnect
      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        send_dap_request 'disconnect',
                      restart: false,
                      terminateDebuggee: false
      when 'chrome'
        @web_sock.send_close_connection
      end

      cleanup_reader
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
                        sourceReference: nil
                      },
                      breakpoints: bps.map{|lineno, condition|
                        {
                          line: lineno,
                          condition: condition
                        }
                      }
      }
    end

    def cleanup_reader
      @reader_thread.raise Detach

      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        @sock.close
      when 'chrome'
        @web_sock.cleanup
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

    HOST = '127.0.0.1'

    def attach_to_cdp_server
      sock = Socket.tcp HOST, @remote_info.port

      Timeout.timeout(TIMEOUT_SEC) do
        sleep 0.001 until @remote_info.debuggee_backlog.join.include? 'Connected'
      end

      @web_sock = WebSocketClient.new sock
      @web_sock.handshake @remote_info.port, '/'
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
      res = find_response :method, 'Debugger.paused', 'C<D'
      @crt_frames = res.dig(:params, :callFrames)
    end

    def assert_eval_result context, expression, expected, frame_idx
      case ENV['RUBY_DEBUG_TEST_UI']
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
        if expected.is_a? String
          expected_val = expected
        else
          expected_val = expected.inspect
        end
        result_val = res.dig(:body, :result)
        assert_equal expected_val, result_val, failure_msg

        expected_type = expected.class.inspect
        result_type = res.dig(:body, :type)
        assert_equal expected_type, result_type, failure_msg
      when 'chrome'
        f_id = @crt_frames.dig(frame_idx, :callFrameId)
        res = send_cdp_request 'Debugger.evaluateOnCallFrame',
                      expression: expression,
                      callFrameId: f_id,
                      objectGroup: context

        failure_msg = FailureMessage.new{create_protocol_message "result:\n#{JSON.pretty_generate res}"}
        if expected.is_a? String
          expected_val = expected
        else
          expected_val = expected.inspect
        end
        result_val = res.dig(:result, :result, :description)
        assert_equal expected_val, result_val, failure_msg

        expected_type = get_expected_type expected
        result_type = res.dig(:result, :result, :type)
        if result_type == 'object'
          result_type = res.dig(:result, :result, :className)
        end
        assert_equal expected_type, result_type, failure_msg
      end
    end

    def get_expected_type obj
      case obj
      when String
        'string'
      when TrueClass, FalseClass
        'boolean'
      when Symbol
        'symbol'
      when Integer, Float
        'number'
      else
        obj.class.inspect
      end
    end

    def send_request command, **kw
      case ENV['RUBY_DEBUG_TEST_UI']
      when 'vscode'
        send type: 'request',
            command: command,
            arguments: kw
      when 'chrome'
        send method: command,
            params: kw
      end
    end

    def send_dap_request command, **kw
      send_request command, **kw

      # TODO: Return the response for "stepBack"
      return if command == "stepBack"

      res = find_crt_dap_response

      # TODO: Check the reason StackTrace response fails validation
      unless command == "stackTrace"
        command_name = command[0].upcase + command[1..-1]
        assert_dap_response("#{command_name}Response".to_sym, res)
      end

      res
    end

    def send_cdp_request command, **kw
      send_request command, **kw
      res = find_crt_cdp_response
      assert_cdp_response(command, res)
      res
    end

    def send **kw
      case ENV['RUBY_DEBUG_TEST_UI']
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
            types = get_ruby_type prop[:type]
            types.each{|type|
              raise ValidationError, "Expected #{property} to be kind of #{types.join}" unless property.is_a? type
            }
            validate_ property, prop[:properties]
          else
            raise ValidationError, "Expected to include `#{name}` in responses" unless prop.fetch(:optional, false)
          end
        }
      end

      def get_ruby_type type
        case type
        when 'string'
          [String]
        when 'integer'
          [Integer]
        when 'boolean'
          [TrueClass, FalseClass]
        when 'object'
          [Hash]
        when 'array'
          [Array]
        when 'any'
          [Object]
        end
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
  end
end

# frozen_string_literal: true

require 'json'
require 'digest/sha1'
require 'base64'
require 'securerandom'
require 'stringio'
require 'open3'
require 'tmpdir'
require 'set'

module DEBUGGER__
  module CDP_Utils
    def safe_eval objectGroup, expr, bind: nil
      if objectGroup == 'completion'
        case expr
        when 'this'
          return {
            className: "Window",
            description: "Window",
            objectId: SecureRandom.hex,
            type: "object"
          }, nil, nil
        when /\(function\si\(e\).*\(\"string\"\)/
          return {
            type: 'object',
            value: [
              {
                items: String.instance_methods,
              }
            ]
          }, nil, nil
        when /\(function\si\(e\).*\(\"number\"\)/
          return {
            type: 'object',
            value: [
              {
                items: Integer.instance_methods,
              }
            ]
          }, nil, nil
        when /\(function\si\(e\).*\(\"boolean\"\)/
          items = Set.new
          TrueClass.instance_methods.each{|m| items << m}
          FalseClass.instance_methods.each{|m| items << m}
          return {
            type: 'object',
            value: [
              {
                items: items.to_a,
              }
            ]
          }, nil, nil
        end
      end
      if expr == "(async function(){ await 1; })()"
        # To get `Runtime.callFunctionOn` from Chrome, this message is required.
        return {
          type: "object",
          subtype: "error",
          className: "EvalError",
          description: "EvalError: Possible side-effect in debug-evaluate",
          objectId: SecureRandom.hex
        },
        {
          exceptionId: SecureRandom.hex,
          text: "Uncaught",
          lineNumber: -1,
          columnNumber: -1,
          scriptId: SecureRandom.hex,
          exception: {
            type: "object",
            subtype: "error",
            className: "EvalError",
            description: "EvalError: Possible side-effect in debug-evaluate",
            objectId: SecureRandom.hex
          }
        }, nil
      end
      b = bind || @bind
      result = {}
      exc = nil
      begin
        orig_stdout = $stdout
        $stdout = StringIO.new
        result = b.eval expr
      rescue Exception => e
        result = e
        bt = result.backtrace.map{|e| "    #{e}\n"}
        lineno = 0
        if l = bt.first.match('.*:(\d+):in .*')
          lineno = l[1].to_i
        end
        exc = {
          exceptionId: 1,
          text: 'Uncaught',
          lineNumber: lineno - 1,
          columnNumber: 0,
          exception: evaluate_result(result),
        }
      ensure
        output = $stdout.string
        $stdout = orig_stdout
      end
      [evaluate_result(result), exc, output]
    end

    def evaluate_result r
      v = variable nil, r
      v[:value]
    end

    def getProperties oid
      result = []
      prop = []

      if obj = @obj_map[oid]
        case obj
        when Array
          result = obj.map.with_index{|o, i|
            variable i.to_s, o
          }
        when Hash
          result = obj.map{|k, v|
            variable(k, v)
          }
        when Struct
          result = obj.members.map{|m|
            variable(m, obj[m])
          }
        when String
          prop = [
            internalProperty('#length', obj.length),
            internalProperty('#encoding', obj.encoding)
          ]
        when Class, Module
          result = obj.instance_variables.map{|iv|
            variable(iv, obj.instance_variable_get(iv))
          }
          prop = [internalProperty('%ancestors', obj.ancestors[1..])]
        when Range
          prop = [
            internalProperty('#begin', obj.begin),
            internalProperty('#end', obj.end),
          ]
        end

        result += obj.instance_variables.map{|iv|
          variable(iv, obj.instance_variable_get(iv))
        }
        prop += [internalProperty('#class', obj.class)]
      end
      [result, prop]
    end

    def variable_ name, obj, type, description: nil, subtype: nil
      description = DEBUGGER__.safe_inspect(obj) if description.nil?
      oid = rand.to_s
      @obj_map[oid] = obj
      prop = {
        name: name,
        value: {
          type: type,
          description: description,
          value: obj,
          objectId: oid
        },
        configurable: true, # TODO: Change these parts because
        enumerable: true    #       they are not necessarily `true`.
      }

      if type == 'object'
        v = prop[:value]
        v.delete :value
        v[:subtype] = subtype if subtype
        v[:className] = obj.class
      end
      prop
    end

    def internalProperty name, obj
      v = variable name, obj
      v.delete :configurable
      v.delete :enumerable
      v
    end

    def variable name, obj
      case obj
      when Array
        variable_ name, obj, 'object', description: "Array(#{obj.size})", subtype: 'array'
      when Hash
        variable_ name, obj, 'object', description: "Hash(#{obj.size})", subtype: 'map'
      when String
        variable_ name, obj, 'string', description: obj
      when TrueClass, FalseClass
        variable_ name, obj, 'boolean'
      when Symbol
        variable_ name, obj, 'symbol'
      when Integer, Float
        variable_ name, obj, 'number'
      when Regexp
        variable_ name, obj, 'object', subtype: 'regexp'
      when Exception
        bt = nil
        if log = obj.backtrace
          bt = log.map{|e| "    #{e}\n"}.join
        end
        variable_ name, obj, 'object', description: "#{obj.inspect}\n#{bt}", subtype: 'error'
      else
        variable_ name, obj, 'object'
      end
    end
  end

  module UI_CDP
    include CDP_Utils

    SHOW_PROTOCOL = ENV['RUBY_DEBUG_CDP_SHOW_PROTOCOL'] == '1'

    class << self
      def setup_chrome addr
        return if CONFIG[:chrome_path] == ''

        port, path, pid = run_new_chrome
        begin
          s = Socket.tcp '127.0.0.1', port
        rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
          return
        end

        ws_client = WebSocketClient.new(s)
        ws_client.handshake port, path
        ws_client.send id: 1, method: 'Target.getTargets'

        loop do
          res = ws_client.extract_data
          case
          when res['id'] == 1 && target_info = res.dig('result', 'targetInfos')
            page = target_info.find{|t| t['type'] == 'page'}
            ws_client.send id: 2, method: 'Target.attachToTarget',
                          params: {
                            targetId: page['targetId'],
                            flatten: true
                          }
          when res['id'] == 2
            s_id = res.dig('result', 'sessionId')
            ws_client.send sessionId: s_id, id: 3,
                          method: 'Page.enable'
          when res['id'] == 3
            s_id = res['sessionId']
            ws_client.send sessionId: s_id, id: 4,
                          method: 'Page.getFrameTree'
          when res['id'] == 4
            s_id = res['sessionId']
            f_id = res.dig('result', 'frameTree', 'frame', 'id')
            ws_client.send sessionId: s_id, id: 5,
                          method: 'Page.navigate',
                          params: {
                            url: "devtools://devtools/bundled/inspector.html?ws=#{addr}",
                            frameId: f_id
                          }
          when res['method'] == 'Page.loadEventFired'
            break
          end
        end
        pid
      rescue Errno::ENOENT
        nil
      end

      def get_chrome_path
        return CONFIG[:chrome_path] if CONFIG[:chrome_path]

        # The process to check OS is based on `selenium` project.
        case RbConfig::CONFIG['host_os']
        when /mswin|msys|mingw|cygwin|emc/
          'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
        when /darwin|mac os/
          '/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome'
        when /linux/
          'google-chrome'
        else
          raise "Unsupported OS"
        end
      end

      def run_new_chrome
        dir = Dir.mktmpdir
        # The command line flags are based on: https://developer.mozilla.org/en-US/docs/Tools/Remote_Debugging/Chrome_Desktop#connecting
        stdin, stdout, stderr, wait_thr = *Open3.popen3("#{get_chrome_path} --remote-debugging-port=0 --no-first-run --no-default-browser-check --user-data-dir=#{dir}")
        stdin.close
        stdout.close

        data = stderr.readpartial 4096
        if data.match /DevTools listening on ws:\/\/127.0.0.1:(\d+)(.*)/
          port = $1
          path = $2
        end
        stderr.close

        at_exit{
          CONFIG[:skip_path] = [//] # skip all
          FileUtils.rm_rf dir
        }

        [port, path, wait_thr.pid]
      end
    end

    class WebSocketClient
      def initialize s
        @sock = s
      end

      def handshake port, path
        key = SecureRandom.hex(11)
        @sock.print "GET #{path} HTTP/1.1\r\nHost: 127.0.0.1:#{port}\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: #{key}==\r\n\r\n"
        res = @sock.readpartial 4092
        $stderr.puts '[>]' + res if SHOW_PROTOCOL

        if res.match /^Sec-WebSocket-Accept: (.*)\r\n/
          correct_key = Base64.strict_encode64 Digest::SHA1.digest "#{key}==258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
          raise "The Sec-WebSocket-Accept value: #{$1} is not valid" unless $1 == correct_key
        else
          raise "Unknown response: #{res}"
        end
      end

      def send **msg
        msg = JSON.generate(msg)
        frame = []
        fin = 0b10000000
        opcode = 0b00000001
        frame << fin + opcode

        mask = 0b10000000 # A client must mask all frames in a WebSocket Protocol.
        bytesize = msg.bytesize
        if bytesize < 126
          payload_len = bytesize
        elsif bytesize < 2 ** 16
          payload_len = 0b01111110
          ex_payload_len = [bytesize].pack('n*').bytes
        else
          payload_len = 0b01111111
          ex_payload_len = [bytesize].pack('Q>').bytes
        end

        frame << mask + payload_len
        frame.push *ex_payload_len if ex_payload_len

        frame.push *masking_key = 4.times.map{rand(1..255)}
        masked = []
        msg.bytes.each_with_index do |b, i|
          masked << (b ^ masking_key[i % 4])
        end

        frame.push *masked
        @sock.print frame.pack 'c*'
      end

      def extract_data
        first_group = @sock.getbyte
        fin = first_group & 0b10000000 != 128
        raise 'Unsupported' if fin
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

        data = JSON.parse @sock.read payload_len
        $stderr.puts '[>]' + data.inspect if SHOW_PROTOCOL
        data
      end
    end

    class Detach < StandardError
    end

    class WebSocketServer
      def initialize s
        @sock = s
      end

      def handshake
        req = @sock.readpartial 4096
        $stderr.puts '[>]' + req if SHOW_PROTOCOL

        if req.match /^Sec-WebSocket-Key: (.*)\r\n/
          accept = Base64.strict_encode64 Digest::SHA1.digest "#{$1}258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
          @sock.print "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: #{accept}\r\n\r\n"
        else
          "Unknown request: #{req}"
        end
      end

      def send **msg
        msg = JSON.generate(msg)
        frame = []
        fin = 0b10000000
        opcode = 0b00000001
        frame << fin + opcode

        mask = 0b00000000 # A server must not mask any frames in a WebSocket Protocol.
        bytesize = msg.bytesize
        if bytesize < 126
          payload_len = bytesize
        elsif bytesize < 2 ** 16
          payload_len = 0b01111110
          ex_payload_len = [bytesize].pack('n*').bytes
        elsif bytesize < 2 ** 64
          payload_len = 0b01111111
          ex_payload_len = [bytesize].pack('Q>').bytes
        else
          raise 'Over size'
        end

        frame << mask + payload_len
        frame.push *ex_payload_len if ex_payload_len
        frame.push *msg.bytes
        @sock.print frame.pack 'c*'
      end

      def extract_data
        first_group = @sock.getbyte
        fin = first_group & 0b10000000 != 128
        raise 'Unsupported' if fin

        opcode = first_group & 0b00001111
        raise Detach if opcode == 8
        raise "Unsupported: #{opcode}" unless opcode == 1

        second_group = @sock.getbyte
        mask = second_group & 0b10000000 == 128
        raise 'The client must mask all frames' unless mask
        payload_len = second_group & 0b01111111
        # TODO: Support other payload_lengths
        if payload_len == 126
          payload_len = @sock.gets(2).unpack('n*')[0]
        end

        masking_key = []
        4.times { masking_key << @sock.getbyte }
        unmasked = []
        payload_len.times do |n|
          masked = @sock.getbyte
          unmasked << (masked ^ masking_key[n % 4])
        end
        JSON.parse unmasked.pack 'c*'
      end
    end

    def send_response req, **res
      if res.empty?
        @ws_server.send id: req['id'], result: {}
      else
        @ws_server.send id: req['id'], result: res
      end
    end

    def send_fail_response req, **res
      @ws_server.send id: req['id'], error: res
    end

    def send_event method, **params
      if params.empty?
        @ws_server.send method: method, params: {}
      else
        @ws_server.send method: method, params: params
      end
    end

    INVALID_REQUEST = -32600
    RESERVED_WORDS = %w[
      BEGIN    class    ensure   nil      self     when
      END      def      false    not      super    while
      alias    defined? for      or       then     yield
      and      do       if       redo     true     __LINE__
      begin    else     in       rescue   undef    __FILE__
      break    elsif    module   retry    unless   __ENCODING__
      case     end      next     return   until
    ].freeze

    def process
      bps = {}
      @src_map = {}
      @obj_map = {}
      @bind = TOPLEVEL_BINDING.dup
      loop do
        req = @ws_server.extract_data
        $stderr.puts '[>]' + req.inspect if SHOW_PROTOCOL

        case req['method']

        ## boot/configuration
        when 'Page.getResourceTree'
          path = File.absolute_path($0)
          src = File.read(path)
          @src_map[path] = src
          send_response req,
                        frameTree: {
                          frame: {
                            id: SecureRandom.hex(16),
                            loaderId: SecureRandom.hex(16),
                            url: 'http://debuggee/',
                            securityOrigin: 'http://debuggee',
                            mimeType: 'text/plain' },
                          resources: [
                          ]
                        }
          send_event 'Debugger.scriptParsed',
                      scriptId: path,
                      url: "http://debuggee#{path}",
                      startLine: 0,
                      startColumn: 0,
                      endLine: src.count("\n"),
                      endColumn: 0,
                      executionContextId: 1,
                      hash: src.hash
          send_event 'Runtime.executionContextCreated',
                      context: {
                        id: 1,
                        origin: "http://#{@addr}",
                        name: '',
                        uniqueId: SecureRandom.hex
                      }
        when 'Debugger.getScriptSource'
          s_id = req.dig('params', 'scriptId')
          src = get_source_code s_id
          send_response req, scriptSource: src
          @q_msg << req
        when 'Page.startScreencast', 'Emulation.setTouchEmulationEnabled', 'Emulation.setEmitTouchEventsForMouse',
          'Runtime.compileScript', 'Page.getResourceContent', 'Overlay.setPausedInDebuggerMessage',
          'Runtime.releaseObjectGroup', 'Runtime.discardConsoleEntries', 'Log.clear', 'Runtime.releaseObject'
          send_response req

        ## control
        when 'Debugger.resume'
          @q_msg << 'c'
          @q_msg << req
          send_response req
          send_event 'Debugger.resumed'
        when 'Debugger.stepOver'
          begin
            @session.check_postmortem
            @q_msg << 'n'
            send_response req
            send_event 'Debugger.resumed'
          rescue PostmortemError
            send_fail_response req,
                              code: INVALID_REQUEST,
                              message: "'stepOver' is not supported while postmortem mode"
          ensure
            @q_msg << req
          end
        when 'Debugger.stepInto'
          begin
            @session.check_postmortem
            @q_msg << 's'
            send_response req
            send_event 'Debugger.resumed'
          rescue PostmortemError
            send_fail_response req,
                              code: INVALID_REQUEST,
                              message: "'stepInto' is not supported while postmortem mode"
          ensure
            @q_msg << req
          end
        when 'Debugger.stepOut'
          begin
            @session.check_postmortem
            @q_msg << 'fin'
            send_response req
            send_event 'Debugger.resumed'
          rescue PostmortemError
            send_fail_response req,
                              code: INVALID_REQUEST,
                              message: "'stepOut' is not supported while postmortem mode"
          ensure
            @q_msg << req
          end
        when 'Debugger.setSkipAllPauses'
          skip = req.dig('params', 'skip')
          if skip
            deactivate_bp
          else
            activate_bp bps
          end
          send_response req

        # breakpoint
        when 'Debugger.getPossibleBreakpoints'
          s_id = req.dig('params', 'start', 'scriptId')
          line = req.dig('params', 'start', 'lineNumber')
          src = get_source_code s_id
          end_line = src.count("\n")
          line = end_line  if line > end_line
          send_response req,
                        locations: [
                          { scriptId: s_id,
                            lineNumber: line,
                          }
                        ]
        when 'Debugger.setBreakpointByUrl'
          line = req.dig('params', 'lineNumber')
          url = req.dig('params', 'url')
          locations = []
          if url.match /http:\/\/debuggee(.*)/
            path = $1
            cond = req.dig('params', 'condition')
            src = get_source_code path
            end_line = src.count("\n")
            line = end_line  if line > end_line
            b_id = "1:#{line}:#{path}"
            if cond != ''
              SESSION.add_line_breakpoint(path, line + 1, cond: cond)
            else
              SESSION.add_line_breakpoint(path, line + 1)
            end
            bps[b_id] = bps.size
            locations << {scriptId: path, lineNumber: line}
          else
            b_id = "1:#{line}:#{url}"
          end
          send_response req,
                        breakpointId: b_id,
                        locations: locations
        when 'Debugger.removeBreakpoint'
          b_id = req.dig('params', 'breakpointId')
          bps = del_bp bps, b_id
          send_response req
        when 'Debugger.setBreakpointsActive'
          active = req.dig('params', 'active')
          if active
            activate_bp bps
          else
            deactivate_bp # TODO: Change this part because catch breakpoints should not be deactivated.
          end
          send_response req
        when 'Debugger.setPauseOnExceptions'
          state = req.dig('params', 'state')
          ex = 'Exception'
          case state
          when 'none'
            @q_msg << 'config postmortem = false'
            bps = del_bp bps, ex
          when 'uncaught'
            @q_msg << 'config postmortem = true'
            bps = del_bp bps, ex
          when 'all'
            @q_msg << 'config postmortem = false'
            SESSION.add_catch_breakpoint ex
            bps[ex] = bps.size
          end
          send_response req

        when 'Debugger.evaluateOnCallFrame'
          @q_msg << req
        when 'Runtime.getProperties'
          oid = req.dig('params', 'objectId')
          if @obj_map.has_key? oid
            result, internalProperties = getProperties oid
            send_response req,
                          result: result,
                          internalProperties: internalProperties
          else
            @q_msg << req
          end
        when 'Runtime.callFunctionOn'
          args = req.dig('params', 'arguments', 0, 'value')
          oid = req.dig('params', 'objectId')
          value = []
          case args
          when 'array'
            value = [
              {
                items: Array.instance_methods,
              }
            ]
          when 'map'
            value = [
              {
                items: Hash.instance_methods,
              }
            ]
          when 'regexp'
            value = [
              {
                items: Regexp.instance_methods,
              }
            ]
          else
            if obj = @obj_map[oid]
              value = [
                {
                  items: obj.methods,
                  title: 'keywords'
                }
              ]
            else
              value = [
                {
                  items: Object.constants.map{|c| c.to_s}
                },
                {
                  items: RESERVED_WORDS,
                  title: 'keywords'
                }
              ]
            end
          end
          send_response req,
                        result: {
                          type: 'object',
                          value: value
                        }
        when 'Runtime.globalLexicalScopeNames'
          send_response req,
                        names: global_variables
        when 'Runtime.evaluate'
          og = req.dig('params', 'objectGroup')
          expr = req.dig('params', 'expression')
          result, exc, output = safe_eval og, expr
          send_response req,
                        result: result,
                        exceptionDetails: exc
        end
      end
    rescue Detach
      @q_msg << 'continue'
    end

    def del_bp bps, k
      return bps unless idx = bps[k]

      bps.delete k
      bps.each_key{|i| bps[i] -= 1 if bps[i] > idx}
      @q_msg << "del #{idx}"
      bps
    end

    def get_source_code path
      return @src_map[path] if @src_map[path]

      src = File.read(path)
      @src_map[path] = src
      src
    end

    def activate_bp bps
      bps.each_key{|k|
        if k.match /^\d+:(\d+):(.*)/
          line = $1
          path = $2
          SESSION.add_line_breakpoint(path, line.to_i + 1)
        else
          SESSION.add_catch_breakpoint 'Exception'
        end
      }
    end

    def deactivate_bp
      @q_msg << 'del'
      @q_ans << 'y'
    end

    def cleanup_reader
      Process.kill :KILL, @chrome_pid if @chrome_pid
    end

    ## Called by the SESSION thread

    def readline prompt
      return 'c' unless @q_msg

      @q_msg.pop || 'kill!'
    end

    def respond req, **result
      send_response req, **result
    end

    def respond_fail req, **result
      send_fail_response req, **result
    end

    def fire_event event, **result
      if result.empty?
        send_event event
      else
        send_event event, **result
      end
    end

    def sock skip: false
      yield $stderr
    end

    def puts result
      # STDERR.puts "puts: #{result}"
      # send_event 'output', category: 'stderr', output: "PUTS!!: " + result.to_s
    end
  end

  class Session
    def fail_response req, **result
      @ui.respond_fail req, **result
      return :retry
    end

    INVALID_PARAMS = -32602

    def process_protocol_request req
      case req['method']
      when 'Debugger.stepOver', 'Debugger.stepInto', 'Debugger.stepOut', 'Debugger.resume', 'Debugger.getScriptSource'
        @tc << [:cdp, :backtrace, req]
      when 'Debugger.evaluateOnCallFrame'
        frame_id = req.dig('params', 'callFrameId')
        objectGroup = req.dig('params', 'objectGroup')
        if fid = @frame_map[frame_id]
          expr = req.dig('params', 'expression')
          @tc << [:cdp, :evaluate, req, fid, expr, objectGroup]
        else
          fail_response req,
                        code: INVALID_PARAMS,
                        message: "'callFrameId' is an invalid"
        end
      when 'Runtime.getProperties'
        oid = req.dig('params', 'objectId')
        if ref = @obj_map[oid]
          case ref[0]
          when 'local'
            frame_id = ref[1]
            fid = @frame_map[frame_id]
            @tc << [:cdp, :scope, req, fid]
          when 'properties'
            @tc << [:cdp, :properties, req, oid]
          when 'script', 'global'
            # TODO: Support script and global types
            @ui.respond req
            return :retry
          else
            raise "Unknown type: #{ref.inspect}"
          end
        else
          fail_response req,
                        code: INVALID_PARAMS,
                        message: "'objectId' is an invalid"
        end
      end
    end

    def cdp_event args
      type, req, result = args

      case type
      when :backtrace
        result[:callFrames].each.with_index do |frame, i|
          frame_id = frame[:callFrameId]
          @frame_map[frame_id] = i
          s_id = frame.dig(:location, :scriptId)
          if File.exist?(s_id) && !@script_paths.include?(s_id)
            src = File.read(s_id)
            @ui.fire_event 'Debugger.scriptParsed',
                            scriptId: s_id,
                            url: frame[:url],
                            startLine: 0,
                            startColumn: 0,
                            endLine: src.count("\n"),
                            endColumn: 0,
                            executionContextId: @script_paths.size + 1,
                            hash: src.hash
            @script_paths << s_id
          end

          frame[:scopeChain].each {|s|
            oid = s.dig(:object, :objectId)
            @obj_map[oid] = [s[:type], frame_id]
          }
        end

        if oid = result.dig(:data, :objectId)
          @obj_map[oid] = ['properties']
        end
        @ui.fire_event 'Debugger.paused', **result
      when :evaluate
        message = result.delete :message
        if message
          fail_response req,
                        code: INVALID_PARAMS,
                        message: message
        else
          rs = result.dig(:response, :result)
          [rs].each{|obj|
            if oid = obj[:objectId]
              @obj_map[oid] = ['properties']
            end
          }
          @ui.respond req, **result[:response]

          out = result[:output]
          if out && !out.empty?
            @ui.fire_event 'Runtime.consoleAPICalled',
                            type: 'log',
                            args: [
                              type: out.class,
                              value: out
                            ],
                            executionContextId: 1, # Change this number if something goes wrong.
                            timestamp: Time.now.to_f
          end
        end
      when :scope
        result.each{|obj|
          if oid = obj.dig(:value, :objectId)
            @obj_map[oid] = ['properties']
          end
        }
        @ui.respond req, result: result
      when :properties
        result.each_value{|v|
          v.each{|obj|
            if oid = obj.dig(:value, :objectId)
              @obj_map[oid] = ['properties']
            end
          }
        }
        @ui.respond req, **result
      end
    end
  end

  class ThreadClient
    include CDP_Utils

    def process_cdp args
      type = args.shift
      req = args.shift

      case type
      when :backtrace
        exception = nil
        result = {
          reason: 'other',
          callFrames: @target_frames.map.with_index{|frame, i|
            exception = frame.raised_exception if frame == current_frame && frame.has_raised_exception

            path = frame.realpath || frame.path
            if path.match /<internal:(.*)>/
              path = $1
            end

            if frame.iseq.nil?
              lineno = 0
            else
              lineno = frame.iseq.first_line - 1
            end

            {
              callFrameId: SecureRandom.hex(16),
              functionName: frame.name,
              functionLocation: {
                scriptId: path,
                lineNumber: lineno
              },
              location: {
                scriptId: path,
                lineNumber: frame.location.lineno - 1 # The line number is 0-based.
              },
              url: "http://debuggee#{path}",
              scopeChain: [
                {
                  type: 'local',
                  object: {
                    type: 'object',
                    objectId: rand.to_s
                  }
                },
                {
                  type: 'script',
                  object: {
                    type: 'object',
                    objectId: rand.to_s
                  }
                },
                {
                  type: 'global',
                  object: {
                    type: 'object',
                    objectId: rand.to_s
                  }
                }
              ],
              this: {
                type: 'object'
              }
            }
          }
        }

        if exception
          result[:data] = evaluate_result exception
          result[:reason] = 'exception'
        end
        event! :cdp_result, :backtrace, req, result
      when :evaluate
        res = {}
        fid, expr, objectGroup = args
        frame = @target_frames[fid]
        message = nil

        if frame && (b = frame.binding)
          b = b.dup
          special_local_variables current_frame do |name, var|
            b.local_variable_set(name, var) if /\%/ !~name
          end

          result = nil

          case req.dig('params', 'objectGroup')
          when 'popover'
            case expr
            # Chrome doesn't read instance variables
            when /\A\$\S/
              global_variables.each{|gvar|
                if gvar.to_s == expr
                  result = eval(gvar.to_s)
                  break false
                end
              } and (message = "Error: Not defined global variable: #{expr.inspect}")
            when /(\A((::[A-Z]|[A-Z])\w*)+)/
              unless result = search_const(b, $1)
                message = "Error: Not defined constants: #{expr.inspect}"
              end
            else
              begin
                # try to check local variables
                b.local_variable_defined?(expr) or raise NameError
                result = b.local_variable_get(expr)
              rescue NameError
                # try to check method
                if b.receiver.respond_to? expr, include_all: true
                  result = b.receiver.method(expr)
                else
                  message = "Error: Can not evaluate: #{expr.inspect}"
                end
              end
            end
            result = evaluate_result result
          else
            result, exc, output = safe_eval objectGroup, expr, bind: b
            res[:exceptionDetails] = exc unless exc.nil?
          end
        else
          result = evaluate_result Exception.new("Error: Can not evaluate on this frame")
        end

        res[:result] = result
        event! :cdp_result, :evaluate, req, message: message, response: res, output: output
      when :scope
        fid = args.shift
        frame = @target_frames[fid]
        if b = frame.binding
          vars = b.local_variables.map{|name|
            v = b.local_variable_get(name)
            variable(name, v)
          }
          special_local_variables frame do |name, val|
            vars.unshift variable(name, val)
          end
          vars.unshift variable('%self', b.receiver)
        elsif lvars = frame.local_variables
          vars = lvars.map{|var, val|
            variable(var, val)
          }
        else
          vars = [variable('%self', frame.self)]
          special_local_variables frame do |name, val|
            vars.unshift variable(name, val)
          end
        end
        event! :cdp_result, :scope, req, vars
      when :properties
        oid = args.shift
        result, internalProperties = getProperties oid
        event! :cdp_result, :properties, req, result: result, internalProperties: internalProperties
      end
    end

    def search_const b, expr
      cs = expr.delete_prefix('::').split('::')
      [Object, *b.eval('Module.nesting')].reverse_each{|mod|
        if cs.all?{|c|
             if mod.const_defined?(c)
               mod = mod.const_get(c)
             else
               false
             end
           }
          # if-body
          return mod
        end
      }
      false
    end
  end
end

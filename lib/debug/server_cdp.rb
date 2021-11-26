# frozen_string_literal: true

require 'json'
require 'digest/sha1'
require 'base64'
require 'securerandom'
require 'stringio'

module DEBUGGER__
  module UI_CDP
    SHOW_PROTOCOL = ENV['RUBY_DEBUG_CDP_SHOW_PROTOCOL'] == '1'

    class Detach < StandardError
    end

    class WebSocket
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
        else
          payload_len = 0b01111111
          ex_payload_len = [bytesize].pack('Q>').bytes
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
        @web_sock.send id: req['id'], result: {}
      else
        @web_sock.send id: req['id'], result: res
      end
    end

    def send_event method, **params
      if params.empty?
        @web_sock.send method: method, params: {}
      else
        @web_sock.send method: method, params: params
      end
    end

    def process
      bps = {}
      @src_map = {}
      loop do
        req = @web_sock.extract_data
        $stderr.puts '[>]' + req.inspect if SHOW_PROTOCOL

        case req['method']

        ## boot/configuration
        when 'Page.getResourceTree'
          abs = File.absolute_path($0)
          src = File.read(abs)
          @src_map[abs] = src
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
                      scriptId: abs,
                      url: "http://debuggee#{abs}",
                      startLine: 0,
                      startColumn: 0,
                      endLine: src.count("\n"),
                      endColumn: 0,
                      executionContextId: 1,
                      hash: src.hash
          send_event 'Runtime.executionContextCreated',
                      context: {
                        id: SecureRandom.hex(16),
                        origin: "http://#{@addr}",
                        name: ''
                      }
        when 'Debugger.getScriptSource'
          s_id = req.dig('params', 'scriptId')
          src = get_source_code s_id
          send_response req, scriptSource: src
          @q_msg << req
        when 'Page.startScreencast', 'Emulation.setTouchEmulationEnabled', 'Emulation.setEmitTouchEventsForMouse',
          'Runtime.compileScript', 'Page.getResourceContent', 'Overlay.setPausedInDebuggerMessage',
          'Runtime.releaseObjectGroup', 'Runtime.discardConsoleEntries', 'Log.clear'
          send_response req

        ## control
        when 'Debugger.resume'
          @q_msg << 'c'
          @q_msg << req
          send_response req
          send_event 'Debugger.resumed'
        when 'Debugger.stepOver'
          @q_msg << 'n'
          @q_msg << req
          send_response req
          send_event 'Debugger.resumed'
        when 'Debugger.stepInto'
          @q_msg << 's'
          @q_msg << req
          send_response req
          send_event 'Debugger.resumed'
        when 'Debugger.stepOut'
          @q_msg << 'fin'
          @q_msg << req
          send_response req
          send_event 'Debugger.resumed'
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
            send_response req,
                          breakpointId: b_id,
                          locations: [
                            scriptId: path,
                            lineNumber: line
                          ]
          else
            b_id = "1:#{line}:#{url}"
            send_response req,
                          breakpointId: b_id,
                          locations: []
          end
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

        when 'Debugger.evaluateOnCallFrame', 'Runtime.getProperties'
          @q_msg << req
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

    ## Called by the SESSION thread

    def readline prompt
      @q_msg.pop || 'kill!'
    end

    def respond req, **result
      send_response req, **result
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
    def process_protocol_request req
      case req['method']
      when 'Debugger.stepOver', 'Debugger.stepInto', 'Debugger.stepOut', 'Debugger.resume', 'Debugger.getScriptSource'
        @tc << [:cdp, :backtrace, req]
      when 'Debugger.evaluateOnCallFrame'
        expr = req.dig('params', 'expression')
        @tc << [:cdp, :evaluate, req, expr]
      when 'Runtime.getProperties'
        oid = req.dig('params', 'objectId')
        case @scope_map[oid]
        when 'local', 'eval'
          @tc << [:cdp, :properties, req, oid]
        when 'script', 'global'
          # TODO: Support script and global types
          @ui.respond req
          return :retry
        else
          raise "Unknown object id #{oid}"
        end
      end
    end

    def cdp_event args
      type, req, result = args

      case type
      when :backtrace
        result[:callFrames].each do |frame|
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
            @scope_map[oid] = s[:type]
          }
        end
        result[:reason] = 'other'
        @ui.fire_event 'Debugger.paused', **result
      when :evaluate
        rs = result.dig(:response, :result)
        [rs].each {|r|
          if oid = r.dig(:objectId)
            @scope_map[oid] = 'eval'
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
      when :properties
        result.each {|r|
          if oid = r.dig(:value, :objectId)
            @scope_map[oid] = 'local' # TODO: Change this part because it is not necessarily `local`.
          end
        }
        @ui.respond req, result: result
      end
    end
  end

  class ThreadClient
    def process_cdp args
      type = args.shift
      req = args.shift

      case type
      when :backtrace
        event! :cdp_result, :backtrace, req, {
          callFrames: @target_frames.map.with_index{|frame, i|
            path = frame.realpath || frame.path
            if path.match /<internal:(.*)>/
              abs = $1
            else
              abs = path
            end

            call_frame = {
              callFrameId: SecureRandom.hex(16),
              functionName: frame.name,
              location: {
                scriptId: abs,
                lineNumber: frame.location.lineno - 1 # The line number is 0-based.
              },
              url: "http://debuggee#{abs}",
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
            call_frame[:scopeChain].each {|s|
              oid = s.dig(:object, :objectId)
              @frame_id_map[oid] = i
            }
            call_frame
          }
        }
      when :evaluate
        res = {}
        expr = args.shift
        begin
          orig_stdout = $stdout
          $stdout = StringIO.new
          result = current_frame.binding.eval(expr.to_s, '(DEBUG CONSOLE)')
        rescue Exception => e
          result = e
          b = result.backtrace.map{|e| "    #{e}\n"}
          line = b.first.match('.*:(\d+):in .*')[1].to_i
          res[:exceptionDetails] = {
            exceptionId: 1,
            text: 'Uncaught',
            lineNumber: line - 1,
            columnNumber: 0,
            exception: evaluate_result(result),
          }
        ensure
          output = $stdout.string
          $stdout = orig_stdout
        end
        res[:result] = evaluate_result(result)
        event! :cdp_result, :evaluate, req, response: res, output: output
      when :properties
        oid = args.shift
        if fid = @frame_id_map[oid]
          frame = @target_frames[fid]
          if b = frame.binding
            vars = b.local_variables.map{|name|
              v = b.local_variable_get(name)
              variable(name, v)
            }
            vars.unshift variable('%raised', frame.raised_exception) if frame.has_raised_exception
            vars.unshift variable('%return', frame.return_value) if frame.has_return_value
            vars.unshift variable('%self', b.receiver)
          elsif lvars = frame.local_variables
            vars = lvars.map{|var, val|
              variable(var, val)
            }
          else
            vars = [variable('%self', frame.self)]
            vars.push variable('%raised', frame.raised_exception) if frame.has_raised_exception
            vars.push variable('%return', frame.return_value) if frame.has_return_value
          end
        elsif objs = @obj_map[oid]
          vars = parse_object(objs)
        else
          raise "Unknown object id #{oid}"
        end
        event! :cdp_result, :properties, req, vars
      end
    end

    def evaluate_result r
      v = variable nil, r
      v[:value]
    end

    def parse_object objs
      case objs
      when Array
        objs.map.with_index{|obj, i| variable i.to_s, obj}
      when Hash
        objs.map{|k, v| variable k, v}
      end
    end

    def variable_ name, obj, type, description: nil, subtype: nil, use_short: true
      prop = {
        name: name,
        value: {
          type: type,
          description: obj.inspect,
          value: obj,
        },
        configurable: true, # TODO: Change these parts because
        enumerable: true    #       they are not necessarily `true`.
      }
      if description && subtype
        v = prop[:value]
        v.delete :value
        v[:description] = description
        v[:subtype] = subtype
        v[:objectId] = oid = rand.to_s
        v[:className] = obj.class
        @obj_map[oid] = obj
      end
      prop
    end

    def variable name, obj
      case obj
      when Array
        variable_ name, obj, 'object', description: "Array(#{obj.size})", subtype: 'array'
      when Hash
        variable_ name, obj, 'object', description: 'Object', subtype: 'map'
      when Range, NilClass, Time
        variable_ name, obj, 'object'
      when String
        variable_ name, obj, 'string', use_short: false
      when Class, Module, Struct
        variable_ name, obj, 'function'
      when TrueClass, FalseClass
        variable_ name, obj, 'boolean'
      when Symbol
        variable_ name, obj, 'symbol'
      when Float
        variable_ name, obj, 'number'
      when Integer
        variable_ name, obj, 'number'
      when Exception
        variable_ name, obj, 'object', description: "#{obj.inspect}\n#{obj.backtrace.map{|e| "    #{e}\n"}.join}", subtype: 'error'
      else
        variable_ name, obj, 'undefined'
      end
    end
  end
end

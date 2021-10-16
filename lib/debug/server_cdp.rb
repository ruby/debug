# frozen_string_literal: true

require 'json'
require 'digest/sha1'
require 'base64'
require 'securerandom'

module DEBUGGER__
  module UI_CDP
    SHOW_PROTOCOL = ENV['RUBY_DEBUG_CDP_SHOW_PROTOCOL'] == '1'

    def cdp_handshake
      CONFIG.set_config no_color: true

      req = @sock.readpartial 4096
      $stderr.puts '[>]' + req if SHOW_PROTOCOL

      if req.match /^Sec-WebSocket-Key: (.*)\r\n/
        accept = Base64.strict_encode64 Digest::SHA1.digest "#{$1}258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        @sock.print "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: #{accept}\r\n\r\n"
      else
        "Unknown request: #{req}"
      end
    end

    def send_response req, **res
      if res.empty?
        send id: req['id'], result: {}
      else
        send id: req['id'], result: res
      end
    end

    def send_event method, **params
      if params.empty?
        send method: method, params: {}
      else
        send method: method, params: params
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

    def process
      loop do
        first_group = @sock.getbyte
        fin = first_group & 0b10000000 != 128
        raise 'Unsupported' if fin
        opcode = first_group & 0b00001111
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
        req = JSON.parse unmasked.pack 'c*'

        $stderr.puts '[>]' + req.inspect if SHOW_PROTOCOL
        bps = []

        case req['method']

        ## boot/configuration
        when 'Page.getResourceTree'
          abs = File.absolute_path($0)
          src = File.read(abs)
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
                      endLine: src.count('\n'),
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
          src = File.read(s_id)
          send_response req, scriptSource: src
          @q_msg << req
        when 'Page.startScreencast', 'Emulation.setTouchEmulationEnabled', 'Emulation.setEmitTouchEventsForMouse',
          'Runtime.compileScript', 'Page.getResourceContent', 'Overlay.setPausedInDebuggerMessage',
          'Debugger.setBreakpointsActive', 'Runtime.releaseObjectGroup'
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

        # breakpoint
        when 'Debugger.getPossibleBreakpoints'
          s_id = req.dig('params', 'start', 'scriptId')
          line = req.dig('params', 'lineNumber')
          send_response req,
                        locations: [
                          { scriptId: s_id,
                            lineNumber: line,
                          }
                        ]
        when 'Debugger.setBreakpointByUrl'
          line = req.dig('params', 'lineNumber')
          path = req.dig('params', 'url').match('http://debuggee(.*)')[1]
          cond = req.dig('params', 'condition')
          if cond != ''
            bps << SESSION.add_line_breakpoint(path, line + 1, cond: cond)
          else
            bps << SESSION.add_line_breakpoint(path, line + 1)
          end
          send_response req,
                        breakpointId: (bps.size - 1).to_s,
                        locations: [
                          scriptId: path,
                          lineNumber: line
                        ]
        when 'Debugger.removeBreakpoint'
          b_id = req.dig('params', 'breakpointId')
          @q_msg << "del #{b_id}"
          send_response req

        when 'Debugger.evaluateOnCallFrame', 'Runtime.getProperties'
          @q_msg << req
        end
      end
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
        case oid
        when /(\d?):local/
          @tc << [:cdp, :properties, req, $1.to_i]
        when /\d?:script/
          # TODO: Support a script type
          @ui.respond req
          return :retry
        when /\d?:global/
          # TODO: Support a global type
          @ui.respond req
          return :retry
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
                            endLine: src.count('\n'),
                            endColumn: 0,
                            executionContextId: @script_paths.size + 1,
                            hash: src.hash
            @script_paths << s_id
          end
        end
        result[:reason] = 'other'
        @ui.fire_event 'Debugger.paused', **result
      when :evaluate
        @ui.respond req, result: result
      when :properties
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

            local_scope = {
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
                    objectId: "#{i}:local"
                  }
                },
                {
                  type: 'script',
                  object: {
                    type: 'object',
                    objectId: "#{i}:script"
                  }
                },
                {
                  type: 'global',
                  object: {
                    type: 'object',
                    objectId: "#{i}:global"
                  }
                }
              ],
              this: {
                type: 'object'
              }
            }
          }
        }
      when :evaluate
        expr = args.shift
        begin
          result = current_frame.binding.eval(expr.to_s, '(DEBUG CONSOLE)')
        rescue Exception => e
          result = e
        end
        event! :cdp_result, :evaluate, req, evaluate_result(result)
      when :properties
        fid = args.shift
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
        event! :cdp_result, :properties, req, vars
      end
    end

    def evaluate_result r
      v = variable nil, r
      v[:value]
    end

    def variable_ name, obj, type, use_short: true
      {
        name: name,
        value: {
          type: type,
          value: DEBUGGER__.short_inspect(obj, use_short)
        },
        configurable: true,
        enumerable: true
      }
    end

    def variable name, obj
      case obj
      when Array, Hash, Range, NilClass, Time
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
      else
        variable_ name, obj, 'undefined'
      end
    end
  end
end

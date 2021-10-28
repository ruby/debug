# frozen_string_literal: true

require 'json'

module DEBUGGER__
  module UI_DAP
    SHOW_PROTOCOL = ENV['RUBY_DEBUG_DAP_SHOW_PROTOCOL'] == '1'

    def show_protocol dir, msg
      if SHOW_PROTOCOL
        $stderr.puts "\##{Process.pid}:[#{dir}] #{msg}"
      end
    end

    def dap_setup bytes
      CONFIG.set_config no_color: true
      @seq = 0

      show_protocol :>, bytes
      req = JSON.load(bytes)

      # capability
      send_response(req,
             ## Supported
             supportsConfigurationDoneRequest: true,
             supportsFunctionBreakpoints: true,
             supportsConditionalBreakpoints: true,
             supportTerminateDebuggee: true,
             supportsTerminateRequest: true,
             exceptionBreakpointFilters: [
               {
                 filter: 'any',
                 label: 'rescue any exception',
                 #supportsCondition: true,
                 #conditionDescription: '',
               },
               {
                 filter: 'RuntimeError',
                 label: 'rescue RuntimeError',
                 default: true,
                 #supportsCondition: true,
                 #conditionDescription: '',
               },
             ],
             supportsExceptionFilterOptions: true,
             supportsStepBack: true,

             ## Will be supported
             # supportsExceptionOptions: true,
             # supportsHitConditionalBreakpoints:
             # supportsEvaluateForHovers:
             # supportsSetVariable: true,
             # supportSuspendDebuggee:
             # supportsLogPoints:
             # supportsLoadedSourcesRequest:
             # supportsDataBreakpoints:
             # supportsBreakpointLocationsRequest:

             ## Possible?
             # supportsRestartFrame:
             # supportsCompletionsRequest:
             # completionTriggerCharacters:
             # supportsModulesRequest:
             # additionalModuleColumns:
             # supportedChecksumAlgorithms:
             # supportsRestartRequest:
             # supportsValueFormattingOptions:
             # supportsExceptionInfoRequest:
             # supportsDelayedStackTraceLoading:
             # supportsTerminateThreadsRequest:
             # supportsSetExpression:
             # supportsClipboardContext:

             ## Never
             # supportsGotoTargetsRequest:
             # supportsStepInTargetsRequest:
             # supportsReadMemoryRequest:
             # supportsDisassembleRequest:
             # supportsCancelRequest:
             # supportsSteppingGranularity:
             # supportsInstructionBreakpoints:
      )
      send_event 'initialized'
    end

    def send **kw
      kw[:seq] = @seq += 1
      str = JSON.dump(kw)
      show_protocol '<', str
      @sock.write "Content-Length: #{str.size}\r\n\r\n#{str}"
    end

    def send_response req, success: true, **kw
      if kw.empty?
        send type: 'response',
             command: req['command'],
             request_seq: req['seq'],
             success: success,
             message: success ? 'Success' : 'Failed'
      else
        send type: 'response',
             command: req['command'],
             request_seq: req['seq'],
             success: success,
             message: success ? 'Success' : 'Failed',
             body: kw
      end
    end

    def send_event name, **kw
      if kw.empty?
        send type: 'event', event: name
      else
        send type: 'event', event: name, body: kw
      end
    end

    class RetryBecauseCantRead < Exception
    end

    def recv_request
      begin
        r = IO.select([@sock])

        @session.process_group.sync do
          raise RetryBecauseCantRead unless IO.select([@sock], nil, nil, 0)

          case header = @sock.gets
          when /Content-Length: (\d+)/
            b = @sock.read(2)
            raise b.inspect unless b == "\r\n"

            l = @sock.read(s = $1.to_i)
            show_protocol :>, l
            JSON.load(l)
          when nil
            nil
          else
            raise "unrecognized line: #{l} (#{l.size} bytes)"
          end
        end
      rescue RetryBecauseCantRead
        retry
      end
    end

    def process
      while req = recv_request
        raise "not a request: #{req.inpsect}" unless req['type'] == 'request'
        args = req.dig('arguments')

        case req['command']

        ## boot/configuration
        when 'launch'
          send_response req
          @is_attach = false
        when 'attach'
          send_response req
          Process.kill(:SIGURG, Process.pid)
          @is_attach = true
        when 'setBreakpoints'
          path = args.dig('source', 'path')
          bp_args = args['breakpoints']
          bps = []
          bp_args.each{|bp|
            line = bp['line']
            if cond = bp['condition']
              bps << SESSION.add_line_breakpoint(path, line, cond: cond)
            else
              bps << SESSION.add_line_breakpoint(path, line)
            end
          }
          send_response req, breakpoints: (bps.map do |bp| {verified: true,} end)
        when 'setFunctionBreakpoints'
          send_response req
        when 'setExceptionBreakpoints'
          process_filter = ->(filter_id) {
            case filter_id
            when 'any'
              bp = SESSION.add_catch_breakpoint 'Exception'
            when 'RuntimeError'
              bp = SESSION.add_catch_breakpoint 'RuntimeError'
            else
              bp = nil
            end
            {
              verified: bp ? true : false,
              message: bp.inspect,
            }
          }

          filters = args.fetch('filters').map {|filter_id|
            process_filter.call(filter_id)
          }

          filters += args.fetch('filterOptions', {}).map{|bp_info|
            process_filter.call(bp_info.dig('filterId'))
          }

          send_response req, breakpoints: filters
        when 'configurationDone'
          send_response req
          if defined?(@is_attach) && @is_attach
            @q_msg << 'p'
            send_event 'stopped', reason: 'pause',
                                  threadId: 1,
                                  allThreadsStopped: true
          else
            @q_msg << 'continue'
          end
        when 'disconnect'
          if args.fetch("terminateDebuggee", false)
            @q_msg << 'kill!'
          else
            @q_msg << 'continue'
          end
          send_response req

        ## control
        when 'continue'
          @q_msg << 'c'
          send_response req, allThreadsContinued: true
        when 'next'
          @q_msg << 'n'
          send_response req
        when 'stepIn'
          @q_msg << 's'
          send_response req
        when 'stepOut'
          @q_msg << 'fin'
          send_response req
        when 'terminate'
          send_response req
          exit
        when 'pause'
          send_response req
          Process.kill(:SIGURG, Process.pid)
        when 'reverseContinue'
          send_response req,
                        success: false, message: 'cancelled',
                        result: "Reverse Continue is not supported. Only \"Step back\" is supported."
        when 'stepBack'
          @q_msg << req

        ## query
        when 'threads'
          send_response req, threads: SESSION.managed_thread_clients.map{|tc|
            { id: tc.id,
              name: tc.name,
            }
          }

        when 'stackTrace',
             'scopes',
             'variables',
             'evaluate',
             'source'
          @q_msg << req

        else
          raise "Unknown request: #{req.inspect}"
        end
      end
    end

    ## called by the SESSION thread

    def readline prompt
      @q_msg.pop || 'kill!'
    end

    def sock skip: false
      yield $stderr
    end

    def respond req, res
      send_response(req, **res)
    end

    def puts result
      # STDERR.puts "puts: #{result}"
      # send_event 'output', category: 'stderr', output: "PUTS!!: " + result.to_s
    end

    def event type, *args
      case type
      when :suspend_bp
        _i, bp, tid = *args
        if bp.kind_of?(CatchBreakpoint)
          reason = 'exception'
          text = bp.description
        else
          reason = 'breakpoint'
          text = bp ? bp.description : 'temporary bp'
        end

        send_event 'stopped', reason: reason,
                              description: text,
                              text: text,
                              threadId: tid,
                              allThreadsStopped: true
      when :suspend_trap
        _sig, tid = *args
        send_event 'stopped', reason: 'pause',
                              threadId: tid,
                              allThreadsStopped: true
      when :suspended
        tid, = *args
        send_event 'stopped', reason: 'step',
                              threadId: tid,
                              allThreadsStopped: true
      end
    end
  end

  class Session
    def find_waiting_tc id
      @th_clients.each{|th, tc|
        return tc if tc.id == id && tc.waiting?
      }
      return nil
    end

    def fail_response req, **kw
      @ui.respond req, success: false, **kw
      return :retry
    end

    def process_protocol_request req
      case req['command']
      when 'stepBack'
        if @tc.recorder&.can_step_back?
          @tc << [:step, :back]
        else
          fail_response req, message: 'cancelled'
        end

      when 'stackTrace'
        tid = req.dig('arguments', 'threadId')
        if tc = find_waiting_tc(tid)
          tc << [:dap, :backtrace, req]
        else
          fail_response req
        end
      when 'scopes'
        frame_id = req.dig('arguments', 'frameId')
        if @frame_map[frame_id]
          tid, fid = @frame_map[frame_id]
          if tc = find_waiting_tc(tid)
            tc << [:dap, :scopes, req, fid]
          else
            fail_response req
          end
        else
          fail_response req
        end
      when 'variables'
        varid = req.dig('arguments', 'variablesReference')
        if ref = @var_map[varid]
          case ref[0]
          when :globals
            vars = global_variables.map do |name|
              File.write('/tmp/x', "#{name}\n")
              gv = 'Not implemented yet...'
              {
                name: name,
                value: gv.inspect,
                type: (gv.class.name || gv.class.to_s),
                variablesReference: 0,
              }
            end

            @ui.respond req, {
              variables: vars,
            }
            return :retry

          when :scope
            frame_id = ref[1]
            tid, fid = @frame_map[frame_id]

            if tc = find_waiting_tc(tid)
              tc << [:dap, :scope, req, fid]
            else
              fail_response req
            end

          when :variable
            tid, vid = ref[1], ref[2]

            if tc = find_waiting_tc(tid)
              tc << [:dap, :variable, req, vid]
            else
              fail_response req
            end
          else
            raise "Unknown type: #{ref.inspect}"
          end
        else
          fail_response req
        end
      when 'evaluate'
        frame_id = req.dig('arguments', 'frameId')
        if @frame_map[frame_id]
          tid, fid = @frame_map[frame_id]
          expr = req.dig('arguments', 'expression')
          if tc = find_waiting_tc(tid)
            tc << [:dap, :evaluate, req, fid, expr]
          else
            fail_response req
          end
        else
          fail_response req, result: "can't evaluate"
        end
      when 'source'
        ref = req.dig('arguments', 'sourceReference')
        if src = @src_map[ref]
          @ui.respond req, content: src.join
        else
          fail_response req, message: 'not found...'
        end
        return :retry
      else
        raise "Unknown DAP request: #{req.inspect}"
      end
    end

    def dap_event args
      # puts({dap_event: args}.inspect)
      type, req, result = args

      case type
      when :backtrace
        result[:stackFrames].each.with_index{|fi, i|
          fi[:id] = id = @frame_map.size + 1
          @frame_map[id] = [req.dig('arguments', 'threadId'), i]
          if fi[:source] && src = fi[:source][:sourceReference]
            src_id = @src_map.size + 1
            @src_map[src_id] = src
            fi[:source][:sourceReference] = src_id
          end
        }
        @ui.respond req, result
      when :scopes
        frame_id = req.dig('arguments', 'frameId')
        local_scope = result[:scopes].first
        local_scope[:variablesReference] = id = @var_map.size + 1

        @var_map[id] = [:scope, frame_id]
        @ui.respond req, result
      when :scope
        tid = result.delete :tid
        register_vars result[:variables], tid
        @ui.respond req, result
      when :variable
        tid = result.delete :tid
        register_vars result[:variables], tid
        @ui.respond req, result
      when :evaluate
        tid = result.delete :tid
        register_var result, tid
        @ui.respond req, result
      else
        raise "unsupported: #{args.inspect}"
      end
    end

    def register_var v, tid
      if (tl_vid = v[:variablesReference]) > 0
        vid = @var_map.size + 1
        @var_map[vid] = [:variable, tid, tl_vid]
        v[:variablesReference] = vid
      end
    end

    def register_vars vars, tid
      raise tid.inspect unless tid.kind_of?(Integer)
      vars.each{|v|
        register_var v, tid
      }
    end
  end

  class ThreadClient
    def process_dap args
      # pp tc: self, args: args
      type = args.shift
      req = args.shift

      case type
      when :backtrace
        event! :dap_result, :backtrace, req, {
          stackFrames: @target_frames.map.{|frame|
            path = frame.realpath || frame.path
            ref = frame.file_lines unless path && File.exist?(path)

            {
              # id: ??? # filled by SESSION
              name: frame.name,
              line: frame.location.lineno,
              column: 1,
              source: {
                name: File.basename(frame.path),
                path: path,
                sourceReference: ref,
              },
            }
          }
        }
      when :scopes
        fid = args.shift
        frame = @target_frames[fid]

        lnum =
          if frame.binding
            frame.binding.local_variables.size
          elsif vars = frame.local_variables
            vars.size
          else
            0
          end

        event! :dap_result, :scopes, req, scopes: [{
          name: 'Local variables',
          presentationHint: 'locals',
          # variablesReference: N, # filled by SESSION
          namedVariables: lnum,
          indexedVariables: 0,
          expensive: false,
        }, {
          name: 'Global variables',
          presentationHint: 'globals',
          variablesReference: 1, # GLOBAL
          namedVariables: global_variables.size,
          indexedVariables: 0,
          expensive: false,
        }]
      when :scope
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
        event! :dap_result, :scope, req, variables: vars, tid: self.id

      when :variable
        vid = args.shift
        obj = @var_map[vid]
        if obj
          case req.dig('arguments', 'filter')
          when 'indexed'
            start = req.dig('arguments', 'start') || 0
            count = req.dig('arguments', 'count') || obj.size
            vars = (start ... (start + count)).map{|i|
              variable(i.to_s, obj[i])
            }
          else
            vars = []

            case obj
            when Hash
              vars = obj.map{|k, v|
                variable(DEBUGGER__.short_inspect(k), v)
              }
            when Struct
              vars = obj.members.map{|m|
                variable(m, obj[m])
              }
            when String
              vars = [
                variable('#length', obj.length),
                variable('#encoding', obj.encoding)
              ]
            when Class, Module
              vars = obj.instance_variables.map{|iv|
                variable(iv, obj.instance_variable_get(iv))
              }
              vars.unshift variable('%ancestors', obj.ancestors[1..])
            when Range
              vars = [
                variable('#begin', obj.begin),
                variable('#end', obj.end),
              ]
            end

            vars += obj.instance_variables.map{|iv|
              variable(iv, obj.instance_variable_get(iv))
            }
            vars.unshift variable('#class', obj.class)
          end
        end
        event! :dap_result, :variable, req, variables: (vars || []), tid: self.id

      when :evaluate
        fid, expr = args
        frame = @target_frames[fid]

        if frame && (b = frame.binding)
          begin
            result = b.eval(expr.to_s, '(DEBUG CONSOLE)')
          rescue Exception => e
            result = e
          end
        else
          result = 'can not evaluate on this frame...'
        end
        event! :dap_result, :evaluate, req, tid: self.id, **evaluate_result(result)
      else
        raise "Unknown req: #{args.inspect}"
      end
    end

    def evaluate_result r
      v = variable nil, r
      v.delete(:name)
      v[:result] = DEBUGGER__.short_inspect(r)
      v
    end

    def variable_ name, obj, indexedVariables: 0, namedVariables: 0, use_short: true
      if indexedVariables > 0 || namedVariables > 0
        vid = @var_map.size + 1
        @var_map[vid] = obj
      else
        vid = 0
      end

      ivnum = obj.instance_variables.size

      { name: name,
        value: DEBUGGER__.short_inspect(obj, use_short),
        type: obj.class.name || obj.class.to_s,
        variablesReference: vid,
        indexedVariables: indexedVariables,
        namedVariables: namedVariables + ivnum,
      }
    end

    def variable name, obj
      case obj
      when Array
        variable_ name, obj, indexedVariables: obj.size
      when Hash
        variable_ name, obj, namedVariables: obj.size
      when String
        variable_ name, obj, use_short: false, namedVariables: 3 # #to_str, #length, #encoding
      when Struct
        variable_ name, obj, namedVariables: obj.size
      when Class, Module
        variable_ name, obj, namedVariables: 1 # %ancestors (#ancestors without self)
      when Range
        variable_ name, obj, namedVariables: 2 # #begin, #end
      else
        variable_ name, obj, namedVariables: 1 # #class
      end
    end
  end
end

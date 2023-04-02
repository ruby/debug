module DEBUGGER__
  module RdbgTraceInspector
    module Custom_UI_DAP
      def custom_dap_request_rdbgTraceInspector(req)
        @q_msg << req
      end
    end

    module Custom_Session
      def custom_dap_request_rdbgTraceInspector(req)
        cmd = req.dig('arguments', 'command')
        case cmd
        when 'enable'
          events = req.dig('arguments', 'events')
          evts = []
          events.each{|evt|
            case evt
            when 'line'
              evts << :line
            when 'call'
              evts << :call
              evts << :c_call
              evts << :b_call
            when 'return'
              evts << :return
              evts << :c_return
              evts << :b_return
            else
              raise "unknown trace type #{evt}"
            end
          }
          add_tracer MultiTracer.new @ui, evts
          @ui.respond req, {}
        when 'disable'
          @tracers.values.each{|t|
            if t.type == 'multi'
              t.disable
              break
            end
          }
          @ui.respond req, {}
        when 'collect'
          logs = []
          @tracers.values.each{|t|
            if t.type == 'multi'
              logs = t.log
              break
            end
          }
          @ui.respond req, logs: logs
        else
          raise "unknown command #{cmd}"
        end
        return :retry
      end
    end

    ::DEBUGGER__::UI_DAP.include Custom_UI_DAP
    ::DEBUGGER__::Session.include Custom_Session
  end
end

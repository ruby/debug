module DEBUGGER__
  module RecordInspector
    module Custom_UI_DAP
      def custom_dap_request_rdbgRecordInspector(req)
        @q_msg << req
      end
    end

    module Custom_Session
      def custom_dap_request_rdbgRecordInspector(req)
        cmd = req.dig('arguments', 'command')
        case cmd
        when 'enable'
          request_tc [:record, :on]
          @ui.respond req, {}
        when 'disable'
          request_tc [:record, :off]
          @ui.respond req, {}
        when 'step'
          tid = req.dig('arguments', 'threadId')
          count = req.dig('arguments', 'count')
          if tc = find_waiting_tc(tid)
            tc << [:step, :in, count]
          else
            fail_response req
          end
        when 'stepBack'
          tid = req.dig('arguments', 'threadId')
          count = req.dig('arguments', 'count')
          if tc = find_waiting_tc(tid)
            tc << [:step, :back, count]
          else
            fail_response req
          end
        when 'collect'
          tid = req.dig('arguments', 'threadId')
          if tc = find_waiting_tc(tid)
            tc << [:dap, :rdbgRecordInspector, req]
          else
            fail_response req
          end
        else
          raise "Unknown command #{cmd}"
        end
      end

      def custom_dap_request_event_rdbgRecordInspector(req, result)
        @ui.respond req, result
      end
    end

    module Custom_ThreadClient
      def custom_dap_request_rdbgRecordInspector(req)
        logs = []
        log_index = nil
        unless @recorder.nil?
          log_index = @recorder.log_index
          @recorder.log.each{|frames|
            crt_frame = frames[0]
            logs << {
              name: crt_frame.name,
              location: {
                path: crt_frame.location.path,
                line: crt_frame.location.lineno,
              },
              depth: crt_frame.frame_depth
            }
          }
        end
        event! :protocol_result, :rdbgRecordInspector, req, logs: logs, stoppedIndex: log_index
      end
    end

    ::DEBUGGER__::UI_DAP.include Custom_UI_DAP
    ::DEBUGGER__::Session.include Custom_Session
    ::DEBUGGER__::ThreadClient.include Custom_ThreadClient
  end
end

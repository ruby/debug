# frozen_string_literal: true

require "irb/completion"

module DEBUGGER__
  class Completor
    class << self
      # old IRB completion API
      if defined?(IRB::InputCompletor)
        def retrieve_completion_data(input, binding)
          IRB::InputCompletor.retrieve_completion_data(input, bind: binding).compact
        end
      else
        COMPLETOR = IRB::RegexpCompletor.new

        def retrieve_completion_data(input, binding)
          COMPLETOR.retrieve_completion_data(input, bind: binding, doc_namespace: false).compact
        end
      end
    end
  end
end

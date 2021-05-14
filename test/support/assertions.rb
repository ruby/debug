#frozen_string_literal: true

require "minitest/mock"

module Minitest
  #
  # Custom Minitest assertions
  #
  module Assertions
    def assert test, msg = nil
      self.assertions += 1
      unless test
        msg ||= "Expected #{mu_pp test} to be truthy."
        msg = msg.call if Proc === msg
        begin
          raise Minitest::Assertion, msg
        rescue Assertion
          self.failures << $!
        end
      end
      true
    end
  end
end

# frozen_string_literal: true

require 'test/unit'
require 'tempfile'
require 'securerandom'

require_relative 'utils'
require_relative 'dap_utils'
require_relative 'assertions'

module DEBUGGER__
  class TestCase < Test::Unit::TestCase
    include TestUtils
    include DAP_TestUtils
    include AssertionHelpers

    def setup
      @temp_file = nil
    end

    def teardown
      remove_temp_file
    end

    def remove_temp_file
      File.unlink(@temp_file) if @temp_file
      @temp_file = nil
    end

    def with_extra_tempfile
      t = Tempfile.create([SecureRandom.hex(5), '.rb']).tap do |f|
        f.write(extra_file)
        f.close
      end
      yield t
    ensure
      File.unlink t if t
    end
  end
end

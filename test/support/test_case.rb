# frozen_string_literal: true

require 'test/unit'
require 'tempfile'

require_relative 'utils'
require_relative 'assertions'

module DEBUGGER__
  class TestCase < Test::Unit::TestCase
    include TestUtils
    include AssertionHelpers

    def teardown
      remove_temp_file
    end

    def remove_temp_file
      File.unlink(@temp_file) if @temp_file
      @temp_file = nil
    end

    def temp_file_path
      @temp_file.path
    end

    def write_temp_file(program)
      @temp_file = Tempfile.create(%w[debugger .rb])
      @temp_file.write(program)
      @temp_file.close
    end
  end
end

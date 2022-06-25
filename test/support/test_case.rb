# frozen_string_literal: true

require 'test/unit'
require 'tempfile'
require 'securerandom'

require_relative 'utils'
require_relative 'assertions'

module DEBUGGER__
  class TestCase < Test::Unit::TestCase
    TestInfo = Struct.new(:queue, :mode, :prompt_pattern, :remote_info,
                          :backlog, :last_backlog, :internal_info, :failed_process)

    RemoteInfo = Struct.new(:r, :w, :pid, :sock_path, :port, :reader_thread, :debuggee_backlog)

    MULTITHREADED_TEST = !(%w[1 true].include? ENV['RUBY_DEBUG_TEST_DISABLE_THREADS'])

    include TestUtils
    include AssertionHelpers

    def setup
      @temp_file = nil
    end

    def teardown
      remove_temp_file
    end

    def temp_file_path
      @temp_file.path
    end

    def remove_temp_file
      File.unlink(@temp_file) if @temp_file
      @temp_file = nil
    end

    def write_temp_file(program)
      @temp_file = Tempfile.create(%w[debug- .rb])
      @temp_file.write(program)
      @temp_file.close
    end

    def with_extra_tempfile(*additional_words)
      name = SecureRandom.hex(5) + additional_words.join

      t = Tempfile.create([name, '.rb']).tap do |f|
        f.write(extra_file)
        f.close
      end
      yield t
    ensure
      File.unlink t if t
    end

    LINE_NUMBER_REGEX = /^\s*\d+\| ?/

    def strip_line_num(str)
      str.gsub(LINE_NUMBER_REGEX, '')
    end

    def check_line_num!(program)
      unless program.match?(LINE_NUMBER_REGEX)
        new_program = program_with_line_numbers(program)
        raise "line numbers are required in test script. please update the script with:\n\n#{new_program}"
      end
    end

    def program_with_line_numbers(program)
      lines = program.split("\n")
      lines_with_number = lines.map.with_index do |line, i|
        "#{'%4d' % (i+1)}| #{line}"
      end

      lines_with_number.join("\n")
    end
  end
end

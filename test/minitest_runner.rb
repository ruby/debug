# frozen_string_literal: true

$LOAD_PATH.unshift(__dir__)

require 'minitest'
require 'English'

module DEBUGGER__
  #
  # Helper class to aid running minitest
  #
  class MinitestRunner
    def initialize
      p __dir__
      @test_suites = extract_from_argv { |cmd_arg| test_suite?(cmd_arg) }
    end

    def run
      test_suites.each { |f| require File.expand_path(f) }

      Minitest.run
    end

    def test_suite?(str)
      all_test_suites.include?(str)
    end

    def test_suites
      return all_test_suites if @test_suites.empty?

      @test_suites
    end

    def all_test_suites
      Dir.glob('test/**/*_test.rb')
    end

    def extract_from_argv
      matching, non_matching = $ARGV.partition { |arg| yield(arg) }

      $ARGV.replace(non_matching)

      matching
    end
  end
end

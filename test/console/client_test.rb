# frozen_string_literal: true

require_relative '../support/console_test_case'
require 'stringio'

module DEBUGGER__
  class ClientTest < ConsoleTestCase
    def test_gen_sockpath
      output = with_captured_stdout do
        Client.util("gen-sockpath")
      end

      assert_match(/ruby-debug-/, output)
    end

    def test_list_socks
      output = with_captured_stdout do
        Client.util("list-socks")
      end

      unless output.empty?
        assert_match(/ruby-debug-/, output)
      end
    end

    def test_unknown_command
      stdout = with_captured_stdout do
        stderr = with_captured_stderr do
          begin
            Client.util("fix-my-code")
          rescue Exception => e
            assert_equal SystemExit, e.class
          end
        end

        assert_equal "Unknown utility: fix-my-code\n", stderr
      end

      assert_equal "", stdout
    end

    def with_captured_stdout
      original_stdout = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original_stdout
    end

    def with_captured_stderr
      original_stderr = $stderr
      $stderr = StringIO.new
      yield
      $stderr.string
    ensure
      $stderr = original_stderr
    end
  end
end

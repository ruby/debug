# frozen_string_literal: true

require_relative 'support/test_case'
require 'test/unit/rr'
require 'stringio'

module DEBUGGER__
  class ClientTest < TestCase
    def test_init_command_with_bash
      stub(Client).current_shell { :bash }
      output = with_captured_stdout do
        Client.util("init")
      end

      assert_match /bash/, output
      assert_no_match /fish/, output
    end

    def test_init_command_with_fish
      stub(Client).current_shell { :fish }
      output = with_captured_stdout do
        Client.util("init")
      end

      assert_match /fish/, output
      assert_no_match /bash/, output
    end

    def test_init_command_with_argument_with_bash
      stub(Client).current_shell { :bash }
      output = with_captured_stdout do
        Client.util("init", argv: ["-"])
      end

      assert_match /export/, output
      assert_match /prelude/, output
      assert_no_match /set -x/, output
    end

    def test_init_command_with_argument_with_fish
      stub(Client).current_shell { :fish }
      output = with_captured_stdout do
        Client.util("init", argv: ["-"])
      end

      assert_match /set -x/, output
      assert_match /prelude/, output
      assert_no_match /export/, output
    end

    def with_captured_stdout
      original_stdout = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original_stdout
    end
  end
end

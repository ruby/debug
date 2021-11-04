# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class EditTest < TestCase
    def program
      <<~RUBY
      1| a = 1
      RUBY
    end

    def test_edit_opens_the_editor
      ENV["EDITOR"] = "null_editor"

      debug_code(program, remote: false) do
        type "edit"
        assert_debugger_out(/command: null_editor/)
        type "continue"
      end
    end

    def test_edit_shows_warning_when_the_file_can_not_be_found
      ENV["EDITOR"] = "null_editor"

      debug_code(program, remote: false) do
        type "edit foo.rb"
        assert_debugger_out(/not found/)
        type "continue"
      end
    end

    def test_edit_shows_warning_when_editor_env_is_not_set
      ENV["EDITOR"] = nil

      debug_code(program, remote: false) do
        type "edit"
        assert_debugger_out(/can not find editor setting/)
        type "continue"
      end
    end
  end
end

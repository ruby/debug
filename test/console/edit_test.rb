# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class EditTest < ConsoleTestCase
    def program
      <<~RUBY
      1| a = 1
      RUBY
    end

    def test_edit_opens_the_editor
      ENV["EDITOR"] = "null_editor"

      debug_code(program, remote: false) do
        type "edit"
        assert_line_text(/command: null_editor/)
        type "continue"
      end
    end

    def test_edit_shows_warning_when_the_file_can_not_be_found
      ENV["EDITOR"] = "null_editor"

      debug_code(program, remote: false) do
        type "edit foo.rb"
        assert_line_text(/not found/)
        type "continue"
      end
    end

    def test_edit_shows_warning_when_editor_env_is_not_set
      ENV["EDITOR"] = nil

      debug_code(program, remote: false) do
        type "edit"
        assert_line_text(/can not find editor setting/)
        type "continue"
      end
    end
  end
end

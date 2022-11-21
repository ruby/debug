# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class FrameControlTest < ConsoleTestCase
    def extra_file
      <<~RUBY
      class Foo
        def bar
          baz
        end

        def baz
          10
        end
      end
      RUBY
    end

    def program(extra_file_path)
      <<~RUBY
     1| load "#{extra_file_path}"
     2| Foo.new.bar
     3|
     4| p 1
     5| p 2
     6| p 3
      RUBY
    end

    def test_frame_prints_the_current_frame
      with_extra_tempfile do |extra_file|
        debug_code(program(extra_file.path)) do
          type 'b Foo#baz'
          type 'continue'

          type 'frame'
          assert_line_text(/Foo#baz at/)
          type 'kill!'
        end
      end
    end

    def test_up_moves_up_one_frame
      with_extra_tempfile do |extra_file|
        debug_code(program(extra_file.path)) do
          type 'b Foo#baz'
          type 'continue'

          type 'frame'
          assert_line_text(/Foo#baz at/)
          type 'up'
          assert_line_text(/Foo#bar at/)
          type 'up'
          assert_line_text(/<main> at/)
          type 'frame'
          assert_line_text(/<main> at/)
          type 'kill!'
        end
      end
    end

    def test_up_sets_correct_thread_client_location
      with_extra_tempfile do |extra_file|
        debug_code(program(extra_file.path)) do
          type 'b Foo#bar'
          type 'continue'

          type 'up'
          type 'b 5'
          type 'c'
          assert_line_text(/<main> at/)
          assert_line_num(5)
          type 'kill!'
        end
      end
    end

    def test_down_moves_down_one_frame
      with_extra_tempfile do |extra_file|
        debug_code(program(extra_file.path)) do
          type 'b Foo#baz'
          type 'continue'

          type 'up'
          assert_line_text(/Foo#bar at/)
          type 'up'
          assert_line_text(/<main> at/)
          type 'down'
          assert_line_text(/Foo#bar at/)
          type 'down'
          assert_line_text(/Foo#baz at/)
          type 'kill!'
        end
      end
    end

    def test_down_sets_correct_thread_client_location
      with_extra_tempfile do |extra_file|
        debug_code(program(extra_file.path)) do
          type 'b Foo#bar'
          type 'continue'

          type 'up'
          type 'down'
          type 'b 7'
          type 'c'
          assert_line_num(7)
          assert_line_text(/Foo#baz at/)
          type 'kill!'
        end
      end
    end

    def test_frame_sets_correct_thread_client_location
      with_extra_tempfile do |extra_file|
        debug_code(program(extra_file.path)) do
          type 'b Foo#bar'
          type 'continue'

          type 'frame 1'
          type 'b 5'
          type 'c'
          assert_line_text(/<main> at/)
          assert_line_num(5)
          type 'kill!'
        end
      end
    end
  end
end

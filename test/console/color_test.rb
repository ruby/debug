# frozen_string_literal: true

require_relative '../../lib/debug/color'
require_relative '../../lib/debug/config'
require 'test/unit'
require 'test/unit/rr'

module DEBUGGER__
  class ColorTest < Test::Unit::TestCase
    include Color

    # These constant variable are copied from https://github.com/ruby/irb/blob/master/test/irb/test_color.rb#L9-L18
    CLEAR     = "\e[0m"
    BOLD      = "\e[1m"
    UNDERLINE = "\e[4m"
    REVERSE   = "\e[7m"
    RED       = "\e[31m"
    GREEN     = "\e[32m"
    YELLOW    = "\e[33m"
    BLUE      = "\e[34m"
    MAGENTA   = "\e[35m"
    CYAN      = "\e[36m"

    ENV['TERM'] = 'xterm-256color' # This environment variable is not defined in some platforms such as Ubuntu.

    def test_colored_inspect_color_objects_if_use_colorize
      stub_width_method
      enable_colorable

      dummy_class = Struct.new(:foo) do
        def bar
          @a = foo
        end
      end

      { "#{GREEN}#<struct #{CLEAR} foo#{GREEN}=#{CLEAR}#{RED}#{BOLD}\"#{CLEAR}#{RED}b#{CLEAR}#{RED}#{BOLD}\"#{CLEAR}#{GREEN}>#{CLEAR}\n": dummy_class.new('b'),
        "#{RED}#{BOLD}\"#{CLEAR}#{RED}hoge#{CLEAR}#{RED}#{BOLD}\"#{CLEAR}\n": 'hoge'}.each do |k, v|
        expected = k.to_s
        obj = v
        assert_equal(expected, colored_inspect(obj))
      end
    ensure
      remove_const_SESSION
    end

    def test_colored_inspect_does_not_color_objects_if_do_not_use_colorize
      CONFIG[:no_color] = true
      stub_width_method

      dummy_class = Struct.new(:foo) do
        def bar
          @a = foo
        end
      end

      { "#<struct  foo=\"b\">\n": dummy_class.new('b'),
        "\"hoge\"\n": 'hoge'}.each do |k, v|
        expected = k.to_s
        obj = v
        assert_equal(expected, colored_inspect(obj))
      end
    ensure
      CONFIG[:no_color] = nil
      remove_const_SESSION
    end

    def test_colorize_color_string_if_use_colorize
      enable_colorable

      {
        "#{YELLOW}#{BOLD}#{REVERSE}foo#{CLEAR}": [:YELLOW, :BOLD, :REVERSE],
        "#{MAGENTA}#{BOLD}foo#{CLEAR}": [:MAGENTA, :BOLD],
        "#{GREEN}foo#{CLEAR}": [:GREEN],
        "#{CYAN}#{BOLD}foo#{CLEAR}": [:CYAN, :BOLD],
        "#{BLUE}#{BOLD}foo#{CLEAR}": [:BLUE, :BOLD]
      }.each do |k, v|
        assert_equal(k.to_s, colorize('foo', v))
      end
    end

    def test_colorize_does_not_color_string_if_do_not_use_colorize
      CONFIG[:no_color] = true

      [
        [:YELLOW, :BOLD, :REVERSE],
        [:MAGENTA, :BOLD],
        [:GREEN],
        [:CYAN, :BOLD],
        [:BLUE, :BOLD]
      ].each do |color|
        assert_equal('foo', colorize('foo', color))
      end
    ensure
      CONFIG[:no_color] = nil
    end

    SESSION_class = Struct.new('SESSION', :a)

    private

    def stub_width_method
      DEBUGGER__.const_set('SESSION', SESSION_class)
      stub(::DEBUGGER__::SESSION).width { IO.console_size[1] }
    end

    def remove_const_SESSION
      DEBUGGER__.public_class_method(:remove_const)
      DEBUGGER__.remove_const(:SESSION)
      DEBUGGER__.private_class_method(:remove_const)
    end

    def enable_colorable
      stub($stdout).tty? { true }
    end
  end
end

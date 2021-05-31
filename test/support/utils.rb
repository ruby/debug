# frozen_string_literal: true

require 'pty'
require 'expect'
require 'timeout'

module DEBUGGER__
  module TestUtils
    def type(command)
      @queue.push(command)
    end

    def assert_line_num(expected)
      @queue.push(Proc.new { |result|
        assert_equal(expected, take_number(result))
      })
    end

    def assert_line_text(expected)
      @queue.push(Proc.new { |result|
        assert_match(expected, result)
      })
    end

    def debug_code(program, &block)
      @queue = Queue.new
      block.call
      write_temp_file(program)
      create_pseudo_terminal
    end

    def take_number(sentence)
      sentence.match(/(.*):(.*)\r/)[2].to_i
    end

    DEBUG_MODE = false

    def debug_print msg
      print msg if DEBUG_MODE
    end

    RUBY = RbConfig.ruby

    def create_pseudo_terminal
      lib = "#{__dir__}/../../lib"
      ENV['RUBYOPT'] = "-I #{lib}"
      ENV['RUBY_DEBUG_USE_COLORIZE'] = "false"

      PTY.spawn("#{RUBY} -r debug/run #{temp_file_path}") do |read, write, pid|
        quit = false
        result = nil

        until quit
          read.expect(/(.*)\n|\(rdbg\)/) do |sentence|
            debug_print sentence[0]
            if sentence[0] == '(rdbg)'
              cmd = @queue.pop
              if cmd.is_a?(Proc)
                cmd.call(result)
                cmd = @queue.pop
              end
              write.puts(cmd)
              quit = true if cmd == 'quit'
            elsif sentence[0].include?('=>#0')
              result = sentence[0]
            end
          end
        end
        read.expect(/.*\n/) do |sentence|
          debug_print sentence[0]
        end
        read.expect(%r{(Really quit\? \[Y/n\])}) do |sentence|
          debug_print sentence[0]
          write.puts('y')
        end
        read.expect(/.*\n/) do |sentence|
          debug_print sentence[0]
        end
      end
    rescue NoMethodError
      p "terminal finished without reading 'y'"
      raise
    end
  end
end
